import chronos

type
  ReadHandler*[T] = proc(max: int = -1): Future[T]
  WriteHandler*[T] = proc(data: T): Future[void]
  EofHandler*[T] = proc(data: T): bool

  Stream*[T] = ref object
    reader*: ReadHandler[T]
    writer*: WriteHandler[T]
    isEof*: EofHandler[T]
    atEof*: bool

proc init*[T](stream: type[Stream],
              reader: ReadHandler[T] = nil,
              writer: WriteHandler[T] = nil,
              isEof: EofHandler[T] = nil): stream =
  Stream[T](reader: reader, writer: writer, isEof: isEof)

proc read*[T](s: Stream[T]): Future[T] {.async.} =
  result = await s.reader()
  if not isNil(s.isEof) and s.isEof(result):
    s.atEof = true

proc write*[T](s: Stream, data: T): Future[void] =
  s.writer(data)

proc pipe*[T](s: Stream, sync: Stream): Stream =
  if not s.isSource:
    raise newException(CatchableError, "Invalid source stream")

  if not sync.isSync:
    raise newException(CatchableError, "Invalid sync stream")

  proc piper*() {.async.} =
    while true:
      var data = await s.read()
      if isNil(data):
        return

      sync.write(data)

  asyncCheck piper()

proc isSource*(s: Stream) = not isNil(s.reader)
proc isSync*(s: Stream) = not isNil(s.writer)
proc isDuplex*(s: Stream) = s.isSource and s.isSync
