animated-happiness
==================

(This has nothing to do with animation or happiness. I am awful at
naming things, so I am going to use github's suggested name for now.)

This is the 99 percent perspiration repository of a project --
eventually it will stabilize, I will be happy, and I will clone it
over to a real git repo with a fresh history (and probably give it a
meaningful name).

Motivation
----------

When writing code that does file I/O, it is sometimes important to ensure that
the on-disk data is updated in a manner that makes recovery from partial
updates straightforward, and at the same time the code does not make guarantees
about those updates without taking appropriate steps to minimize the risk of
loss.

Normally a process can perform all of its needed file operations without
interruption. However, the conscientious developer must guard against
abnormal situations. Any number of situations could occur in the middle of an
update:

* The disk runs out of space in the middle of the operation
* A signal comes along and kills the process
* The operating system crashes
* The power fails

Consider a daemon that acts as a network key-value archive. It receives from
its connected peer two kinds of requests: a "get" request and a "put" request.
Each put request includes a key and a value. The key is a short ASCII string,
the value could be an incredibly large value. When the key and the value are
successfully stored, the daemon is to return an "ok" response. Note that a key
is never updated, once it is stored it remains constant.

Each get request includes a key. The daemon is to either respond with "ok" and
the value, or "not found" otherwise. It is not acceptable for the daemon
to return a partial or corrupted response.

The peer is dumb. It is making get requests for keys it never successfully put.
This daemon cannot return anything but "not found" to a get request for a key
that was never completely saved.

A simple implementation that works in most cases would be as follows:

```ruby
class DaemonStorage
  # Prepare to store key
  def put(key)
    @file = File.open("storage/#{key}", 'w')
  end

  # Data could trickle in from the network, so the users of this class
  # will be making several writes instead of one big one.
  def add_data(data)
    @file.write data
  end

  # When the peer is done, close the file.
  def finish_data
    @file.close
  end

  # Return available data for key, or nil if none
  def get(key)
    File.read("storage/#{key}")
  rescue Errno::ENOENT
    nil
  end
end
```

The above will likely meet the guarantees almost all the time. It is, however,
vulnerable to many failures:

* An exception such as a full disk, or the process getting killed, will result
  in a partially written key if there was a put request in process. Subsequent
  get requests for that key will return a partial key; this is contrary to
  the guarantee -- it would be more desireable to report that the key was
  not found.
* An operating system crash or power failure could result in data corruption,
  even if the put request completed successfully. This is because after
  the finish_data method is called the operating system will keep the pending
  data in a write cache, which is periodically flushed to disk. It is during
  that short window when it has not been written to disk that this risk presents
  itself.

Testing for these issues is presently rather difficult. Outside of a sound
understanding of how the code interacts with the filesystem, there are few
ways available to validate an implementation's robustness. Killing a process
often in manual testing is tedious and not certain to catch every possible
failure case. And simulating a power failure by repeatedly pulling the plug
can damage sensitive computer components.

Solution
--------

animated-happiness will be a test extension to easily test for these failure
modes. By monkey-patching IO calls and simulating exceptions and termination at
each point, it can help prove that a given block of code meets guarantees.

Here is one possible way to do it:

```ruby
describe "it stores keys fully or not at all" do
  subject { DaemonStorage.new }
  simulate do
    @safely_stored = nil
    storage = DaemonStorage.new
    storage.put '12345'
    storage.add_data 'abcdef'
    storage.add_data 'ghijkl'
    storage.add_data 'mnopqr'
    storage.finish_data
    @safely_stored = true
  end

  if @safely_stored
    describe 'retrieves key correctly as promised' do
      specify { subject.get('12345').must_equal 'abcdefghijklmnopqr'}
    end
  else
    describe 'will return not found as promised' do
      specify { subject.get('12345').must_be_nil }
    end
  end
end
```

The above describe block will be run several times, once for each IO call,
and once for each success or failure mode. It maintains a counter in memory
of how many IO calls it should permit to be successful, as well as a list of
actions it can take. Initially, the counter is set to 0, so the first IO call
will be unsuccessful. For this IO call, it will first raise an exception, then
it will stop execution of the thread (to simulate being killed by a signal),
then it will undo one or more of the recent IO operations (to simulate an
operating system crash or power failure), then finally it will increment the
counter by 1. Testing is complete when the simulate block runs to completion.

More Complex Examples
---------------------

The above is only limited to one file in one directory, with sequential writes.
More interesting scenarios are possible with multiple files (some, but not
all, files could be updated in the case of an operating system crash).

Thanks
------
* [Cowork Buffalo](http://coworkbuffalo.com) for hosting an
  [OpenHack Buffalo](http://openhack.github.io/buffalo/) on
  [June 18, 2013](http://nextplex.com/buffalo-ny/calendar/events/7413)
