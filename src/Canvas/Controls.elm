module Canvas.Controls exposing (..)

import Html exposing (Html, button, div, text, h1, canvas, img)
import Html.Attributes exposing (id, height, width, style, src, class)
import Html.Events exposing (onClick)

import Svg exposing (svg, circle)
import Svg.Attributes exposing (version, viewBox, fill, x, y, cx, cy, r)

import Canvas.Colours as Colours exposing (Colour)

-- UPDATE

type Msg =
  ColourSelected Colour
  | LineWidthSelected Int
  | ToggleDrawMode


-- VIEW


canvasDivStyle =
  [ ("position", "relative" ) ]

colourStyle index colour selected =
  let
    --Adjust the position up and to the left by 1 pixel to account for
    --the extra width of the border when colour is selected
    posAdjustment = if selected then 1 else 0
    left = 20 + (index % 10 * 30) - posAdjustment
    top = 20 + (index // 10 * 30) - posAdjustment
    border = if selected then "1px solid " ++ colour else ""
    borderRadius = if selected then "2px" else ""
  in
    [ ("width", "25px")
    , ("height", "25px")
    , ("background-color", colour)
    , ("position", "absolute")
    , ("left", (toString left) ++ "px")
    , ("top", (toString top) ++ "px")
    , ("border", border)
    , ("border-radius", borderRadius)
    ]

colourPicker curColour index colour =
  let
    selected = curColour == colour
  in
    div
      [ style (colourStyle index (Colours.toHex colour) selected)
      , onClick (ColourSelected colour) ] []

lineWidthCircle colour size =
  svg
    [ version "1.1", x "0", y "0", viewBox "0 0 50 50" ]
    [ circle [fill (Colours.toHex colour), cx "25", cy "25", r (toString size)] [] ]

pencilStyle index selected =
  let
    posAdjustment = if selected then 1 else 0
    left = 20 + (index % 10 * 30) - posAdjustment
    top = 80 - posAdjustment
    border = if selected then "1px solid #ccc" else ""
    borderRadius = if selected then "2px" else ""
  in
    [ ("width", "25px")
    , ("height", "25px")
    , ("position", "absolute")
    , ("left", (toString left) ++ "px")
    , ("top", (toString top) ++ "px")
    , ("border", border)
    , ("border-radius", borderRadius)
    ]

pencilSize curColour curLineWidth index width =
  let
    selected = width == curLineWidth
  in
    div
      [ style (pencilStyle index selected), onClick (LineWidthSelected width) ] [ lineWidthCircle curColour width ]

eraserStyle =
  [ ("width", "25px")
  , ("height", "25px")
  , ("position", "absolute")
  , ("left", "110px")
  , ("top", "80px") ]

eraser =
  div [ style eraserStyle, onClick (ColourSelected Colours.White) ]
      [ img [ src "eraser.svg", width 25, height 25 ] [] ]

drawDragStyle =
  [ ("width", "25px")
  , ("height", "25px")
  , ("position", "absolute")
  , ("left", "140px")
  , ("top", "80px") ]

drawDrag drawMode =
  div [ style drawDragStyle, onClick ToggleDrawMode ]
    [ img [ src (if drawMode then "drag.svg" else "pencil.svg"), width 25, height 25 ] [] ]

colourPalette : Bool -> Bool -> Colour -> Int -> Html Msg
colourPalette visible selectedDrawMode curColour curLineWidth =
  let
    divstyle =
      if visible then
        [ ("opacity", "1"), ("transition", "opacity 1s") ]
      else
        [ ("opacity", "0"), ("transition", "opacity 1s") ]
  in
    div [ style divstyle ]
      ((List.indexedMap (colourPicker curColour) Colours.allColours) ++
      (List.indexedMap (pencilSize curColour curLineWidth) [5, 10, 22]) ++
      [ eraser
      , drawDrag selectedDrawMode]
      )