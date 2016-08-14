port module Canvas.Ports exposing (..)

import Canvas.Vector exposing (Position)

type alias MouseMovedEvent =
  { mousePos: Position
  , mouseDown: Bool
  }

type alias Line =
  { lastMid : Position
  , lineFrom : Position
  , lineMid : Position
  , colour : String
  , width : Int
  }

type alias WheelEvent =
  { delta : Int
  , mousePos : Position
  }

type alias CanvasState =
  { zoom : Int
  , scale : Float
  , curPos : Position
  }

port loadCanvas : () -> Cmd msg

port canvasMouseMoved : (MouseMovedEvent -> msg) -> Sub msg

port canvasMouseUp : ({} -> msg) -> Sub msg

port canvasMouseDown : (Position -> msg) -> Sub msg

port drawLine : (Line) -> Cmd msg

port wheel : (WheelEvent -> msg) -> Sub msg

port moveCanvas : Position -> Cmd msg

port zoomCanvas : CanvasState -> Cmd msg