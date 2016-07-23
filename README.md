# QuickDraw

A drawing app written in [Elm 0.17][1]

[Click here to play][2]

# Build with npm and gulp

[Install Elm][3]

Download the code with git, then use npm and gulp to build the code:

```
$ git clone https://github.com/alexspurling/quickdraw.git
$ cd quickdraw
$ npm install
### Wait for a ton of dependencies to be downloaded
### Install the gulp cli (if you haven't already)
$ sudo npm install --global gulp-cli
### Build the project
$ gulp build
$ gulp serve
```

Navigate to: [http://localhost:3000/index.html] (note I cannot use the Elm Reactor because I am using ports to manipulate the canvas)

[1]: http://www.elm-lang.org
[2]: https://alexspurling.github.io/quickdraw
[3]: http://elm-lang.org/install