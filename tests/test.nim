# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import strutils, sequtils
import unittest
import chronos
import streams

suite "nimstreams":
  test "reader":
    proc test(): Future[bool] {.async.} =
      var pos = 0
      var source: seq[char] = @['1', '2', '3', '4', '5']
      proc reader(max: int = -1): Future[char] {.async.} =
        result = cast[char](source[pos])
        pos.inc()

      proc isEof(data: char): bool = source.len == 5
      var stream: Stream[char] = Stream.init(reader = reader, isEof = isEof)
      while true:
        var c = await stream.read()
        if stream.atEof:
          break

        check:
          pos == parseInt($c)

      result = true

    check:
      waitFor(test()) == true

  test "writer":
    proc test(): Future[bool] {.async.} =
      var sync: seq[char]
      proc writer(c: char) {.async.} =
        sync.add(c)

      var stream: Stream[char] = Stream.init(writer = writer)
      for c in @['1', '2', '3', '4', '5']:
        await stream.write(c)

      check: sync == @['1', '2', '3', '4', '5']
      result = true

    check:
      waitFor(test()) == true

  test "duplex":
    proc test(): Future[bool] {.async.} =
      var source = newAsyncQueue[char](1)
      proc writer(data: char) {.async.} =
        await source.put(data)

      var pos = 0
      proc reader(max = -1): Future[char] {.async.} =
        result = await source.get()
        pos.inc()

      proc isEof(data: char): bool = pos == 5
      var stream: Stream[char] = Stream.init(reader, writer, isEof)

      var finished = newAsyncEvent()
      proc readerTask() {.async.} =
        while not stream.atEof:
          var c = await stream.read()
          check:
            pos == parseInt($c)
        finished.fire()

      asyncCheck readerTask()

      for c in @['1', '2', '3', '4', '5']:
        await stream.write(c)

      await finished.wait()
      result = true

    check:
      waitFor(test()) == true
