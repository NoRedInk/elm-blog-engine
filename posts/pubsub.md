All programming languages give you some primitives to use as starting points in your own creations.  For example, a language might provide arrays, hashes, and objects that you turn into a system representing students, teachers, and the work that passes between them.

Some languages go a little further in what they provide.  For example, several languages have primitives that represent code in that language.  This opens the doors to using metaprogramming to remake the language into exactly what you need it to be to best solve your problems.  The various Lisps are perfect examples of this.

Now [Elixir](http://elixir-lang.org/) includes _process_ primitives.  These processes are actually inherited from [Erlang](http://www.erlang.org/), which Elixir is built on top of.

The name is a little confusing because you can spin up a "process" from most any language.  That's not the same thing.  In most languages, the word process refers to a thing created and managed by your operating system.  These are completely separate programs.  Operating systems are heavily optimized for creating these programs but they are still pretty heavyweight items.  Elixir processes are much smaller.

You might be wondering if they are more like threads?  Not really.  Threads are still too big and they deal in terms of shared memory.  Shared memory usually involves some kind of locking and this quickly complicates their usage.  Elixir processes share nothing.

Finally, communication is baked in.  Elixir processes can send messages to each other.

In many ways, Elixir processes are closer to objects in Object Oriented languages.  They encapsulate data and it's the interactions among the processes that make up what a system does.  The differences are that processes can act independently of each other, even in parallel, and you are forced to [send messages](http://baddotrobot.com/blog/2012/10/06/sending-messages-vs-method-invocation/) to them.

Let's look at an example.  The following Elixir code launches two processes and has the second one send a message to the first.  We'll examine it in chunks:

    IO.puts "#{inspect self} is a process launching other processes..."

    # ...

This first bit just prints a statement indicating what the _main_ process is about to do.  By main process, I just mean the one that started running your code, as opposed to the other processes we are about to launch.  `inspect self` just shows a unique identifier for each process, so we can tell them apart in the output.

```elixir
    # ...

    receiver = spawn(fn ->
      IO.puts "#{inspect self} is a process listening for messages..."
      receive do
        %{from: from, content: content} ->
          IO.puts "#{inspect self} received this message from #{inspect from}:  "
                  content
      end
    end)

    # ...
```

This code creates our first subprocess.  That new process also prints output regarding its job and before doing what it said it would:  listening for incoming messages.  It will print another line when a message arrives.

    # ...

    spawn(fn ->
      IO.puts "#{inspect self} is a process sending messages..."
      send(receiver, %{from: self, content: "Hello other process!"})
    end)

This creates our second subprocess.  Like the others, it prints what it will do, then does it.  In this case, the job is to deliver a message to the first subprocess.

If we bundle all of that code up in a file called `processes.exs`, it would look like this:

    IO.puts "#{inspect self} is a process launching other processes..."

    receiver = spawn(fn ->
      IO.puts "#{inspect self} is a process listening for messages..."
      receive do
        %{from: from, content: content} ->
          IO.puts "#{inspect self} received this message from #{inspect from}:  "
                  content
      end
    end)

    spawn(fn ->
      IO.puts "#{inspect self} is a process sending messages..."
      send(receiver, %{from: self, content: "Hello other process!"})
    end)

There are three key bits in the code:

* The `spawn()` function launches a new process.  In this case, I have provided anonymous functions for the code I want to run in each one.  A `PID` (Process ID) is returned, which is useful with…
* The `send()` function allows one process to send a message to another process.  The message can be any data.  In this case, I've used a `Map`, which is Elixir's equivalent to Ruby's `Hash`.
* Code inside of `receive do … end` allows a process to listen for incoming messages.  Inside, various clauses [pattern match](http://elixir-lang.org/getting-started/pattern-matching.html) the incoming messages and provide code for handling them.  A listening process will block here until a message arrives that matches one of the patterns or an optional timeout is hit (not shown in this post).

You can see how these pieces interact if you run the code with Elixir 1.2.3:

    $ elixir processes.exs
    #PID is a process launching other processes...
    #PID is a process listening for messages...
    #PID is a process sending messages...
    #PID received this message from #PID:  Hello other process!

This may not look like much yet, but you can build fully distributed systems using just these tools.  Let's prove it by creating a pub/sub messaging system in 30 lines of code.  I'll keep my processes on the same machine for this example, but the code we build up could be used across the network without changes.  Elixir makes that trivial.

## A Pub/Sub Server

Elixir already gives us a way to send messages to individual processes as needed.  Let's say we need a [Publish-Subscribe Channel](http://www.enterpriseintegrationpatterns.com/patterns/messaging/PublishSubscribeChannel.html) though.  In that model, interested processes subscribe to the channel and then, when a message comes in, it is forwarded to all current subscribers.

To give an example of how this could be useful, imagine that we have events arriving that represent student's answers to quiz questions.  The main action is to figure out if the student has answered correctly and respond to them.  Several subsystems may also be interested in the result though.  We may need to update the students mastery scores for the concept that the question covers; we may need to update a teacher's grade book based on how the student did; we might want to record some general metrics useful in determining the overall difficulty of the question.  One way to avoid tightly coupling all of these systems to the evaluation response code, is to allow the latter to _publish_ results that subsystems can _subscribe_ to receive.  If we someday wish to track a new metric that we haven't paid attention to in the past, we can just add another subscriber for the new subsystem.

We need three things to pull this off:

1. We need to `spawn()` a `PubSubServer` process.  Its job will be to track who is subscribed and handle incoming messages.
2. We need a way to send messages to that server process.
3. We need a way to subscribe to messages coming out of the server process.

We'll attack the problem in just that manner.  Let's build up some code in a file called `pub_sub.exs`.  First, we `spawn()` a process:

    defmodule PubSubServer do
      def start do
        spawn(__MODULE__, :run, [[ ]])
      end

      # ...
    end

You've seen `spawn()` before, but there are two differences in this code.  First, I am tucking these functions away in their own module to namespace the API provided.  The other difference is that I have not passed `spawn()` an anonymous function this time, but instead referenced a function using three identifiers.  The first is a module name and I used `__MODULE__` to fetch the name of the current module.  The second is the name of the function to call in that module:  `run()`, which we'll get to in a bit.  Finally, you provide a list of arguments to pass to that function, which in this case is a single argument that is an empty list.

My `start()` function returns what `spawn()` does:  the `PID` of the new process.  We can use that to communicate with the process.  Given that, what would publishing a message look like?

    defmodule PubSubServer do
      # ...

      def publish(server, message) do
        send(server, {:publish, message})
      end

      # ...
    end

This is a trivial wrapper over `send()`.  Why do that?  The caller has the `PID` and it could just call `send()` themselves.  That's true, but by wrapping it we remove the need for the caller to know our internal message format.  We may choose to change that someday and they won't even need to know, as long as they keep calling `publish()`.  For now we've chosen to make messages simple tuples where the first element is an atom describing the message type.  That can be used in pattern matching on the receiving end.

Subscribing is similar, but we'll do a little more for the user:

    defmodule PubSubServer do
      # ...

      def subscribe(server, handler) do
        send(server, {:subscribe, self})
        listen(handler)
      end

      def listen(handler) do
        receive do
          message ->
            handler.(message)
            listen(handler)
        end
      end

      # ...
    end

Again, we `send()` the message on the caller's behalf.  This time we say that `self` is subscribing, which is just how you get the `PID` of the current process in Elixir.  After the message is sent we also fall into a `receive` loop to wait for the incoming messages.  The caller provides an anonymous function that we'll call with each message we receive to invoke whatever code they need.

The `listen()` function might look a little weird if you haven't seen a "loop" in Elixir before.  The language doesn't really have loops, so functions just [recurse to perform some operation repeatedly](http://elixir-lang.org/getting-started/recursion.html).  Because Elixir has [tail call optimization](https://en.wikipedia.org/wiki/Tail_call), this process doesn't add new stack frames and is very efficient.

The outside interface for our code is defined.  We just need that `run()` function with the internal logic we promised in our `spawn()` call.

    defmodule PubSubServer do
      # ...

      def run(subscribers) do
        receive do
          {:publish, message} ->
            Enum.each(subscribers, fn pid -> send(pid, message) end)
            run(subscribers)
          {:subscribe, subscriber} ->
            run([subscriber | subscribers])
        end
      end
    end

This code handles the two types of messages that we made up in the previous functions.  When `:publish` comes in, we forward the message to our list of `subscribers` passed into `run()`.  The `:subscribe` message is how that list grows and it is another slightly tricky Elixir-ism.

I mentioned before that loops are just recursive function calls and we see that again in `run()`.  The interesting new bit is how processes "remember" things.

Elixir's data structures are immutable, so any "change" actually makes a new structure that reflects the differences.  That might leave you wondering how we keep track of which of these structures is current?

The answer is that we pass them as arguments to the recursive calls.  This means that each pass through the loop can learn from what happened in previous passes.  If you recall back to the `start()` function, I passed an empty list to the initial call of `run()`.  Each time a `:subscribe` message comes in, we push the new listener onto the front of the current list as we hand it down to the next call of `run()`.  When a `:publish` message is received, `subscribers` will have accumulated the listeners from all previous times through the loop.

That's it.  We've built a pub/sub system.  All we have to do is prove it.

## When Everything Happens At Once

My first naive thought was to show some example code like this:

    server = PubSubServer.start
    listener_count = 10

    Stream.repeatedly(fn ->
      spawn(fn ->
        PubSubServer.subscribe(server, fn message ->
          IO.puts "#{inspect self} received:  #{message}"
        end)
      end)
    end) |> Enum.take(listener_count)

    PubSubServer.publish(server, "Hello everyone!")

This code fires up our `PubSubServer`, creates a bunch of subscribers, and publishes a message through the system.  The code in the middle may look a bit odd because Elixir doesn't have Ruby's `10.times do … end` iterator.  I recreated it by building an infinite `Stream` that just calls an anonymous function `repeatedly()` and then `take()`ing ten values from it.

But does this code work?  Yes and no, but it's going to look more like no:

    $ elixir pub_sub.exs
    $

The surprised look on my face right now reminds me that I forget to mention one very important detail when I started this discussion:  Elixir processes are fully parallel.  When you call `spawn()` it sets up the new process, but control returns to the caller as soon as it has a `PID` to give you.  The calling code doesn't actually wait for anything to happen in that child process before it goes back to executing instructions in the parent process.

Given that, I introduced two separate timing bugs in the example code above!  Can you puzzle them out?

The first issue reveals itself if we add some print statements to check the timing:

    defmodule PubSubServer do
      # ...

      def run(subscribers) do
        receive do
          {:publish, message} ->
            IO.puts "Publishing..."
            Enum.each(subscribers, fn pid -> send(pid, message) end)
            run(subscribers)
          {:subscribe, subscriber} ->
            IO.puts "Subscribing..."
            run([subscriber | subscribers])
        end
      end
    end

Here's what they tell us:

    $ elixir pub_sub.exs
    Publishing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...

Kind of backwards from what we were aiming for, eh?  As a refresher, here's the problematic code:

    # ...

    Stream.repeatedly(fn ->
      spawn(fn ->
        PubSubServer.subscribe(server, fn message ->
          IO.puts "#{inspect self} received:  #{message}"
        end)
      end)
    end) |> Enum.take(listener_count)

    PubSubServer.publish(server, "Hello everyone!")

The calls to `spawn()` are triggered first, but the main process keeps going as those processes start running.  It finishes the call to `publish()` before the processes can get subscribed and that message is passed on to zero processes.  That's our first problem.

A clumsy fix is just to slow the main process down a touch before it `publish()`es:

    # ...

    # give the subscribers time to get rolling
    :timer.sleep(1_000)

    PubSubServer.publish(server, "Hello everyone!")

OK, the forced sleep is gross, but does it work?  Again, it's an unsatisfying yes and no:

    $ elixir pub_sub.exs
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Publishing...

It's obvious that fixed the ordering problem, but we still don't see the output from our forwarded messages.  This is our second problem.  It's really just the first problem again, but the interaction is less obvious to me.

After `publish()` is called the message starts speeding through the `PubSubServer` and the subscriber processes.  Again though, the main process carries on.  Well, the opposite actually.  Since the call to `publish()` is the last line the main process executes, it exits right after and shuts down the whole virtual machine before the subscriber processes complete their work.

One more sleep will show us that `PubSubServer` has worked fine all along.  Here's the added line:

    # ...

    PubSubServer.publish(server, "Hello everyone!")

    # give the messages time to be written
    :timer.sleep(1_000)

And here's the output we've been waiting for:

    $ elixir pub_sub.exs
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Subscribing...
    Publishing...
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!

I know what you're thinking:  can you do it without the calls to `sleep()`?  Why, yes I can.  Stick around.

There's another way around our use of the second `sleep()`.  If I remove the extra calls to `puts()` and that final `sleep()`, we can still make it work:

    $ elixir --no-halt pub_sub.exs
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    ^C
    BREAK: (a)bort (c)ontinue (p)roc info (i)nfo (l)oaded
           (v)ersion (k)ill (D)b-tables (d)istribution
    q

The difference here is the usage of Elixir's `--no-halt` flag.  Sometimes people write scripts that spin up various processes to do stuff and they want to wait on that work even though the main process is finished.  That's why this flag exists.  It tells Elixir to skip the step of shutting everything down when it falls off the end of the main script.  The virtual machine just keeps running.  You can see that I manually stopped it here by typing `control-c`, `q`, and `return`.

That's still kind of cheating though, right?  Let's roll our sleeves up and really solve these timing issues.

## Knowing What a Process Is Thinking

In order to fix the example code, we need two pieces of knowledge that we don't currently have.  First, we need to know when the `PubSubServer` has ten subscribers.  We want to publish the message after that point, so we need to wait on it to happen.

The second piece of knowledge we need is similar.  We need to know when the subscribers have finished acknowledging that they received the messages from `PubSubServer`.  That's the point when it's safe for us to shutdown.

In other words, we have two cases of needing to know what a process is thinking.  Which leads us to a great rule of thumb:  **if you need to know what an Elixir process is thinking, it needs to tell you**.  We can use this telling strategy to fix up our code.

To gain the first piece of knowledge, we do need to thread a callback through two functions of `PubSubServer`.  Here are the changes:

    defmodule PubSubServer do
      def start(subscriber_callback \\ nil) do
        spawn(__MODULE__, :run, [[ ], subscriber_callback])
      end

      # ...

      def run(subscribers, subscriber_callback) do
        receive do
          {:publish, message} ->
            Enum.each(subscribers, fn pid -> send(pid, message) end)
            run(subscribers, subscriber_callback)
          {:subscribe, subscriber} ->
            if subscriber_callback, do: subscriber_callback.(subscriber)
            run([subscriber | subscribers], subscriber_callback)
        end
      end
    end

The difference here is that we now accept an optional `subscriber_callback` when the server is `start()`ed.  We pass that callback down to `run()` and add it to what we are keeping track of while recursing.  Then, if a callback is provided, we call the function whenever a new process subscribes.

Now we can half-fix the example code:

    # add a callback that sends us a message when someone subscribes
    main = self
    server = PubSubServer.start(fn subscriber ->
      send(main, {:subscriber, subscriber})
    end)
    listener_count = 10

    Stream.repeatedly(fn ->
      spawn(fn ->
        PubSubServer.subscribe(server, fn message ->
          IO.puts "#{inspect self} received:  #{message}"
        end)
      end)
    end) |> Enum.take(listener_count)

    # replace `sleep()` with listening for `listener_count` subscribers
    Stream.repeatedly(fn ->
      receive do
        {:subscriber, _} -> true
      end
    end) |> Enum.take(listener_count)

    PubSubServer.publish(server, "Hello everyone!")

The comments point out the two changes made:  we added a callback that notifies `main` when a process subscribes and we now listen for all of the subscribers to join before we `publish()` a message.  That removes the need to sleep, though we still need the `--no-halt` flag:

    $ elixir --no-halt pub_sub.exs
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    ^C
    BREAK: (a)bort (c)ontinue (p)roc info (i)nfo (l)oaded
           (v)ersion (k)ill (D)b-tables (d)istribution
    q

Doing pretty much the same fix one more time finally banishes the timing issues from our code:

    main = self
    server = PubSubServer.start(fn subscriber ->
      send(main, {:subscriber, subscriber})
    end)
    listener_count = 10

    Stream.repeatedly(fn ->
      spawn(fn ->
        PubSubServer.subscribe(server, fn message ->
          IO.puts "#{inspect self} received:  #{message}"
          send(main, {:written, message})  # notify `main` of the write
        end)
      end)
    end) |> Enum.take(listener_count)

    Stream.repeatedly(fn ->
      receive do
        {:subscriber, _} -> true
      end
    end) |> Enum.take(listener_count)

    PubSubServer.publish(server, "Hello everyone!")

    # wait for `listener_count` writes before we quit
    Stream.repeatedly(fn ->
      receive do
        {:written, _} -> true
      end
    end) |> Enum.take(listener_count)

Again, see the comments.  They point out the new notification and the final pause for incoming messages.

Our example code finally functions as advertised:

    $ elixir pub_sub.exs
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!
    #PID received:  Hello everyone!

## In Your Own Code

You can read through [the final code from this post](https://gist.github.com/JEG2/5517c64ae051092e40e7) if you're curious, but know that it's just a learning tool.  If you really need an Elixir pub/sub system, you should probably borrow [the one the Phoenix web framework uses](https://github.com/phoenixframework/phoenix_pubsub) or at least rework my code in terms of [GenEvent](http://elixir-lang.org/docs/stable/elixir/GenEvent.html), an Elixir tool would allow you to [use supervisors to restart your process in case of failure](http://elixir-lang.org/getting-started/mix-otp/supervisor-and-application.html).

Having these powerful primitives to build on gives you some choices when writing Elixir applications.  In many other languages, the norm would be to add external dependencies to handle pub/sub, queuing, scheduled job execution, and more.  You can still take that path in Elixir too.  It works as it always has.  With Elixir though, you also have the choice of easily meeting your specific need using the tools included with the language.  It's always nice to have options.
