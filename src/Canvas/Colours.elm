module Canvas.Colours exposing (..)

type Colour = Red
  | Pink
  | Purple
  | DeepPurple
  | Indigo
  | Blue
  | LightBlue
  | Cyan
  | Teal
  | Green
  | LightGreen
  | Lime
  | Yellow
  | Amber
  | Orange
  | DeepOrange
  | Brown
  | Grey
  | BlueGrey
  | Black

allColours =
  [ Red
  , Pink
  , Purple
  , DeepPurple
  , Indigo
  , Blue
  , LightBlue
  , Cyan
  , Teal
  , Green
  , LightGreen
  , Lime
  , Yellow
  , Amber
  , Orange
  , DeepOrange
  , Brown
  , Grey
  , BlueGrey
  , Black]

toHex : Colour -> String
toHex colour =
  case colour of
    Red -> "#F6402C"
    Pink -> "#EB1460"
    Purple -> "#9C1AB1"
    DeepPurple -> "#6633B9"
    Indigo -> "#3D4DB7"
    Blue -> "#1093F5"
    LightBlue -> "#00A6F6"
    Cyan -> "#00BBD5"
    Teal -> "#009687"
    Green -> "#46AF4A"
    LightGreen -> "#88C440"
    Lime -> "#CCDD1E"
    Yellow -> "#FFEC16"
    Amber -> "#FFC100"
    Orange -> "#FF9800"
    DeepOrange -> "#FF5505"
    Brown -> "#7A5547"
    Grey -> "#9D9D9D"
    BlueGrey -> "#5E7C8B"
    Black -> "#000000"