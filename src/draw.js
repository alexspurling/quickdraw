var app = Elm.Main.fullscreen();


app.ports.loadCanvas.subscribe(function(foo) {
  console.log("Loading canvas", document.getElementById("mycanvas"))
}