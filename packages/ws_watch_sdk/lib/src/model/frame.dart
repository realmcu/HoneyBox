enum WSFrameDirection { tx, rx }

enum WSFrameKind {
  data,
  ack,
  errAck,
  retry,
  chunk,
  crcError,
  assembleTimeout,
  invalidHeader,
  sequenceConflict
}
