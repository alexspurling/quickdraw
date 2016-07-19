var gulp = require('gulp');
var jshint = require('gulp-jshint');
var concat = require('gulp-concat');
var uglify = require('gulp-uglify');
var rename = require('gulp-rename');
var elm = require('gulp-elm');
var concat = require('gulp-concat-util');
var audiosprite = require('gulp-audiosprite');
var ghPages = require('gulp-gh-pages');
var serve = require('gulp-serve');

gulp.task('elm-init', elm.init);

gulp.task('elm-make', ['elm-init'], function(){
  return gulp.src('src/Main.elm')
    .pipe(elm.make({filetype: 'js'}))
    .pipe(gulp.dest('build'));
});

gulp.task('lint', function() {
  return gulp.src('src/*.js')
    .pipe(jshint())
    .pipe(jshint.reporter('default'));
});

gulp.task('prepare-js', ['lint', 'elm-make'], function() {
  return gulp.src(['build/*.js', 'src/*.js'])
    .pipe(concat('quickdraw.js'))
    .pipe(gulp.dest('build/dist/js'));
});

gulp.task('prepare-html', function() {
  return gulp.src(['src/*.html'])
    .pipe(gulp.dest('build/dist'));
});

gulp.task('build', ['prepare-js', 'prepare-html']);

gulp.task('watch', ['build'], function() {
  gulp.watch('src/*.elm', ['build']);
  gulp.watch('src/*.js', ['build']);
  gulp.watch('src/*.html', ['build']);
});

gulp.task('serve', serve('build/dist'));

gulp.task('deploy', function() {
  gulp.src('build/dist/**/*')
    .pipe(ghPages());
});

gulp.task('default', ['build']);
