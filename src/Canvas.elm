port module Canvas exposing (..)

import Mouse exposing (Position)

type alias MouseMovedEvent =
  { mousePos: Position
  , mouseDown: Bool }

type alias Line =
  { from: Position
  , to: Position
  , colour: String }

port loadCanvas : () -> Cmd msg

port canvasMouseMoved : (MouseMovedEvent -> msg) -> Sub msg

port canvasMouseUp : ({} -> msg) -> Sub msg

port canvasMouseDown : ({} -> msg) -> Sub msg

port drawLine : (Line) -> Cmd msg