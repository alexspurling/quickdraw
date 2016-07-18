port module Canvas exposing (..)

import Mouse exposing (Position)

port loadCanvas : () -> Cmd msg

port canvasMouseMoved : (Position -> msg) -> Sub msg