// What comes down the victory road. A win draws one car, one coat of paint and
// one word of congratulation out of the hat, so the lap that follows a win is
// never quite the lap that followed the last one.
//
// Every car is drawn over 100 units of its length and 45 of its height off the
// road, so they share a road, a ride height and a set of wheels no matter how
// differently they are shaped above the sill. That common ground is: the sill at
// 38.0, the axles wherever the car carries them, wheel arches cut on a radius of
// 8.2 to clear a tyre of 7.9, and bumpers at 33.8. They are all drawn a touch
// longer and rounder than the real things, because a car this small on the page
// reads better as a silhouette than as an accurate one.

type car = {
  name: string, // for reading the code by; nothing renders it
  body: string, // the whole outline, wheel arches cut out of the sill
  glass: string, // the greenhouse, as one pane per side
  seams: array<string>, // pillars and shut lines, drawn over the body
  lamp: string, // the headlamp
  tail: string, // the rear lamp
  bumpers: array<string>,
  axles: (float, float), // where the rear and front wheels sit along the car
}

let f = Belt.Float.toString

// a round lamp, written as a path so a car with square ones can have those
// instead without the renderer needing to know which it is drawing
let dot = (~cx, ~cy, ~rx, ~ry) =>
  `M ${f(cx -. rx)},${f(cy)} a ${f(rx)},${f(ry)} 0 1,0 ${f(rx *. 2.0)},0 ` ++
  `a ${f(rx)},${f(ry)} 0 1,0 ${f(rx *. -2.0)},0 Z`

// A Fiat 500 seen from the side. What is kept from the real thing is where the
// weight sits: the cabin is half the car and it sits over the back axle, the
// roof is a dome with no flat in it, and the nose is barely a nose — a short
// deck off the windscreen that rounds over almost at once. The whole upper line
// from the tail to the windscreen is one continuous sweep, broken only where a
// car has to break: at the screen header and at the scuttle. The beltline sits
// at 15.2 and the sill at 38.0, which leaves the flank enough metal that the car
// does not read as a slim one. The front wheel is pushed well out to 84.5, so
// there is barely any wing left between it and the bumper.
let cinquecento = {
  name: "cinquecento",
  body: "M 5.3,38.0 C 2.8,37.6 1.4,35.8 1.4,33.0 \
C 1.4,28.6 2.5,23.8 4.9,19.6 C 8.9,13.8 14.6,8.4 21.2,4.7 \
C 28.4,1.7 36.8,0.4 45.4,0.4 C 54.0,0.4 60.6,1.5 65.2,3.5 \
C 68.2,7.0 70.6,11.0 72.5,15.2 C 78.0,15.4 83.4,16.0 88.2,17.0 \
C 94.4,18.8 99.0,22.2 101.2,27.4 C 101.6,29.8 101.7,31.8 101.6,33.8 \
C 101.5,36.4 99.9,37.7 97.4,38.0 \
L 92.5,38.0 A 8.2,8.2 0 1,0 76.5,38.0 \
L 28.0,38.0 A 8.2,8.2 0 1,0 12.0,38.0 Z",
  // one pane, running the whole cabin from the windscreen back to where the rear
  // screen lies down on the tail. In a true side view the pillars between them
  // are edge-on and have no width worth filling, so they are drawn as seams over
  // the glass rather than cut out of it — which also keeps them from flashing as
  // bright slivers when the car is only 60px long.
  glass: "M 63.4,5.3 C 66.2,8.6 68.4,11.9 70.2,15.2 L 20.0,15.2 \
C 21.8,11.6 24.0,8.2 26.6,5.6 C 36.6,3.2 52.0,3.0 63.4,5.3 Z",
  seams: [
    "M 58.4,5.1 C 61.2,8.4 63.4,11.7 65.2,15.3", // the windscreen post
    // the door, its shut line running from the roof rail down past the glass
    "M 40.0,3.5 C 39.2,7.9 38.8,11.6 38.6,15.3 C 38.8,22.0 39.0,27.0 39.2,31.6",
    "M 58.0,19.0 L 62.0,19.0", // the handle
  ],
  lamp: dot(~cx=93.0, ~cy=23.4, ~rx=2.5, ~ry=3.0),
  tail: dot(~cx=4.8, ~cy=27.6, ~rx=1.2, ~ry=1.8),
  bumpers: ["M 96.0,33.8 L 101.0,33.8", "M 2.0,33.8 L 7.0,33.8"],
  axles: (20.0, 84.5),
}

// The Panda, which is the 500's opposite in every line and its equal in
// cheapness: no curve anywhere that a straight edge would have done, a roof dead
// flat from end to end, glass that is a rectangle, and a tailgate that stands up
// rather than lies down. Its headlamps are square, so it gets square ones.
let panda = {
  name: "panda",
  body: "M 4.0,38.0 C 2.2,37.6 1.6,36.0 1.6,33.4 \
L 2.6,14.2 C 2.8,11.4 4.2,9.4 6.6,8.2 L 15.2,3.2 \
C 16.6,2.4 18.0,2.0 19.8,2.0 L 66.0,2.0 \
C 68.4,2.0 69.9,2.6 70.9,4.2 L 76.8,13.6 L 95.0,15.6 \
C 98.4,16.2 100.6,18.8 100.9,22.8 L 101.1,33.6 \
C 101.1,36.2 99.6,37.6 97.2,38.0 \
L 92.5,38.0 A 8.2,8.2 0 1,0 76.5,38.0 \
L 27.0,38.0 A 8.2,8.2 0 1,0 11.0,38.0 Z",
  glass: "M 18.6,4.6 L 66.0,4.6 L 74.4,14.0 L 10.6,14.0 Z",
  seams: [
    "M 66.0,4.6 L 74.4,14.0", // the windscreen post
    "M 18.6,4.6 L 10.6,14.0", // and the one at the back of the cabin
    "M 28.4,2.2 L 28.4,14.0 L 28.6,31.2", // the door shut line
    "M 48.0,19.6 L 53.0,19.6", // the handle
  ],
  lamp: "M 90.6,19.8 L 97.4,20.4 L 97.4,25.4 L 90.6,25.4 Z", // square, of course
  tail: "M 3.0,23.0 L 5.6,23.2 L 5.6,28.6 L 3.0,28.6 Z",
  bumpers: ["M 95.6,33.8 L 100.8,33.8", "M 2.2,33.8 L 7.4,33.8"],
  axles: (19.0, 84.5),
}

// An open two-seater with the roof down, which is the only one of the four that
// has a hole in its outline: the body line drops off the rear deck into the
// cockpit, runs along the door top and climbs out again at the scuttle. Long
// bonnet, short tail, and the screen a raked pane standing on its own.
let spider = {
  name: "spider",
  body: "M 3.2,38.0 C 1.5,37.5 0.9,35.7 1.3,32.8 \
C 1.9,26.6 3.8,21.6 7.0,18.2 C 13.0,12.8 21.4,9.6 31.0,8.8 \
C 33.4,8.8 34.6,10.4 34.8,13.2 L 35.0,17.2 L 57.0,17.2 \
C 59.4,17.2 61.0,17.6 62.0,18.4 L 95.6,20.6 \
C 99.0,21.2 101.2,23.4 101.4,27.0 L 101.5,33.6 \
C 101.5,36.2 100.1,37.6 97.6,38.0 \
L 92.6,38.0 A 8.2,8.2 0 1,0 76.6,38.0 \
L 27.4,38.0 A 8.2,8.2 0 1,0 11.4,38.0 Z",
  // the screen, standing on the scuttle on its own with no roof to carry back.
  // It is drawn as the wraparound it is: wide where it meets the scuttle,
  // narrower and further back at the header rail.
  glass: "M 57.8,17.2 L 54.6,6.2 C 55.0,5.2 56.0,4.8 57.2,4.8 \
L 61.6,5.0 L 68.4,17.3 Z",
  seams: [
    "M 54.6,6.2 L 57.8,17.2", // the screen frame, up its trailing edge
    "M 39.0,17.6 C 39.4,22.6 39.6,27.0 39.8,31.4", // the door shut line
    "M 10.0,26.4 C 34.0,24.6 66.0,25.0 96.0,27.0", // the crease along the flank
    "M 46.0,21.4 L 51.0,21.6", // the handle
  ],
  lamp: dot(~cx=94.0, ~cy=25.4, ~rx=2.6, ~ry=2.8),
  tail: dot(~cx=4.2, ~cy=29.0, ~rx=1.3, ~ry=1.7),
  bumpers: ["M 96.4,33.8 L 101.2,33.8", "M 1.6,33.8 L 6.4,33.8"],
  axles: (19.5, 84.5),
}

// The van every Italian trade ran on: one box, the driver sat over the front
// wheel, and nothing ahead of the windscreen worth calling a bonnet. It is by
// far the tallest of the four, so it has the most flank of any of them and only
// one window on that flank — the rest is the painted side of the load bay.
let furgoncino = {
  name: "furgoncino",
  body: "M 3.4,38.0 C 1.6,37.6 1.0,36.0 1.0,33.4 L 1.2,8.6 \
C 1.4,5.4 3.2,3.0 6.4,1.8 C 9.0,0.9 12.0,0.5 15.6,0.5 L 84.6,0.5 \
C 88.6,0.5 91.6,1.4 93.6,3.2 C 96.6,6.6 99.0,10.6 100.4,15.2 \
C 101.2,18.4 101.6,21.6 101.6,25.0 L 101.6,33.6 \
C 101.6,36.2 100.2,37.6 97.8,38.0 \
L 92.4,38.0 A 8.2,8.2 0 1,0 76.4,38.0 \
L 25.6,38.0 A 8.2,8.2 0 1,0 9.6,38.0 Z",
  glass: "M 64.6,4.2 L 84.4,4.2 C 87.2,4.4 89.0,5.0 90.2,6.4 \
C 92.4,9.0 94.2,11.8 95.4,14.8 L 64.6,14.8 Z",
  seams: [
    "M 59.6,1.0 L 60.0,14.8 L 60.2,31.6", // the cab door shut line
    "M 3.0,26.4 L 98.6,27.4", // the rubbing strip down the flank
    "M 51.0,19.6 L 56.0,19.8", // the handle
  ],
  lamp: dot(~cx=97.2, ~cy=21.8, ~rx=2.2, ~ry=2.6),
  tail: dot(~cx=3.4, ~cy=24.6, ~rx=1.2, ~ry=2.0),
  bumpers: ["M 96.6,33.8 L 101.4,33.8", "M 1.4,33.8 L 6.2,33.8"],
  axles: (17.6, 84.2),
}

let cars = [cinquecento, panda, spider, furgoncino]

// The coats of paint, near enough the names they were sold under. Each is light
// enough to take the ink outline in either theme, and brings a hub cap tinted to
// match, since a 500's steel wheels came painted like the body.
type paint = {name: string, body: string, hub: string}

let paints = [
  {name: "giallo positano", body: "#f5c518", hub: "#fdf3d0"},
  {name: "rosso corallo", body: "#e05a4a", hub: "#ffe4dd"},
  {name: "azzurro capri", body: "#6fb2d8", hub: "#e4f2fb"},
  {name: "verde chiaro", body: "#83b96e", hub: "#e9f5e1"},
  {name: "bianco ghiaccio", body: "#eceada", hub: "#fbfaf2"},
  {name: "celeste marina", body: "#9ed0d6", hub: "#eefafb"},
  {name: "arancio vesuvio", body: "#ec8340", hub: "#ffeada"},
  {name: "sabbia", body: "#dcc08a", hub: "#f8eeda"},
  {name: "amaranto", body: "#c25f74", hub: "#ffe7ee"},
]

// What the tricolore says. All of them cheer the round rather than the player,
// so none has to guess who it is talking to.
let messages = [
  "Congratulazioni!",
  "Complimenti!",
  "Perfetto!",
  "Che meraviglia!",
  "Fantastico!",
  "Splendido!",
  "Magnifico!",
  "Evviva!",
  "Che bello!",
]

// one of anything, drawn fresh. Only ever called once a win, so the lap keeps
// whatever it was dealt for as long as it runs.
let anyOf = items =>
  items->Belt.Array.getUnsafe(
    Js.Math.floor_int(Js.Math.random() *. Belt.Int.toFloat(items->Belt.Array.length)),
  )
