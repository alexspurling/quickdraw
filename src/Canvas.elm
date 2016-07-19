port module Canvas exposing (..)

import Mouse exposing (Position)

port loadCanvas : () -> Cmd msg

port canvasMouseMoved : (Position -> msg) -> Sub msg

port canvasMouseUp : ({} -> msg) -> Sub msg

port canvasMouseDown : ({} -> msg) -> Sub msg