var app = Elm.Main.fullscreen();


app.ports.loadCanvas.subscribe(function(foo) {
  var canvas = document.getElementById("mycanvas");
  var ctx = canvas.getContext("2d");

  console.log("Loading canvas", canvas);

  canvas.addEventListener("mousemove", function (e) {
      var canvasX = e.clientX - canvas.offsetLeft;
      var canvasY = e.clientY - canvas.offsetTop;
      app.ports.canvasMouseMoved.send({x: canvasX, y: canvasY});
  }, false);

  canvas.addEventListener("mousedown", function (e) {
      console.log("Mouse down", e);
      app.ports.canvasMouseDown.send({});
  }, false);

  canvas.addEventListener("mouseup", function (e) {
      console.log("Mouse up", e);
      app.ports.canvasMouseUp.send({});
  }, false);
});