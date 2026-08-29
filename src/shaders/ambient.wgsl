// Document-level ambient field for everything outside the hero.
//
// Volumetric march through a turbulent field: each step folds the sample point
// with a sin-based turbulence, then accumulates light divided by the distance to
// the folded sheet. That accumulation produces thin bright cores with coloured
// halos, tone mapped down to sit behind page content.
//
// SDR only. The hero owns the extended-range path; this treatment is still being
// settled, and an unused HDR branch here would only be dead code.
//
// The pointer steers the ray and adds a local attractor, so the field answers the
// cursor. Scroll drifts the field forward.
//
// Original work. FragCoord/@Xor shaders informed the technique family only; no
// third-party shader source is included (see docs/SHADER_PORTING.md).

struct AmbientParams {
  time: f32,
  aspect: f32,
  scroll: f32,
  quality: f32,
  pointer: vec2f,
  viewport: vec2f,
}

@group(0) @binding(0)
var<uniform> ambient: AmbientParams;

fn hash21(p: vec2f) -> f32 {
  let h = dot(p, vec2f(127.1, 311.7));
  return fract(sin(h) * 43758.5453123);
}

// Restricted three-stop ramp: teal, indigo, warm amber. A full cosine hue wheel
// covers the whole spectrum and turns the field into a rainbow wash; three stops
// give variety while staying inside the site's palette.
//
// This field is SDR by design. Extended-range output stays with the hero until
// the ambient treatment is settled; carrying an unused HDR path here would just
// be dead code to maintain.
fn ramp(h: f32) -> vec3f {
  let teal = vec3f(0.16, 0.52, 0.68);
  let indigo = vec3f(0.40, 0.34, 0.80);
  let amber = vec3f(0.85, 0.58, 0.32);

  let x = fract(h) * 3.0;
  let w_teal = max(0.0, 1.0 - min(abs(x - 0.0), abs(x - 3.0)));
  let w_indigo = max(0.0, 1.0 - abs(x - 1.0));
  let w_amber = max(0.0, 1.0 - abs(x - 2.0));
  let total = max(w_teal + w_indigo + w_amber, 0.0001);

  return (teal * w_teal + indigo * w_indigo + amber * w_amber) / total;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let screen = (uv - 0.5) * vec2f(ambient.aspect, 1.0);
  let t = ambient.time * 0.05;
  // Scroll nudges the field forward. Deep travel per scroll unit makes the whole
  // volume churn while scrolling, which reads as motion sickness rather than
  // parallax, so the coupling stays small.
  let travel = ambient.time * 0.030 + ambient.scroll * 0.28;

  let steps = select(8, select(12, 16, ambient.quality > 0.88), ambient.quality > 0.62);

  // Pointer steers the ray and pulls a brighter knot toward the cursor.
  let pointer = (ambient.pointer - 0.5) * vec2f(ambient.aspect, 1.0);
  let to_pointer = screen - pointer;
  let pointer_falloff = exp(-length(to_pointer) * 2.2);

  var direction = normalize(vec3f(screen * 1.15, 1.0));
  direction = normalize(direction + vec3f(pointer * 0.22, 0.0));



  // Per-pixel jitter on the march start. Without it, a 16-step march quantises
  // into visible shells that crawl across the screen as the field moves.
  // Fixed per-pixel dither, not re-rolled each frame. Animated noise on a slow
  // field is what reads as fizzing rather than as motion.
  let jitter = hash21(floor(uv * ambient.viewport));
  var z = 0.55 + jitter * 0.018;
  // Brightness and colour are accumulated separately. Accumulating tinted light
  // directly averages hue along the ray, so every pixel converges on the palette's
  // base colour and one hue ends up owning every highlight. Instead the march
  // sums density, and carries an intensity-weighted hue coordinate that stays
  // smooth across neighbouring pixels.
  var density = 0.0;
  var hue_weighted = 0.0;

  for (var i = 0; i < 16; i += 1) {
    if (i >= steps) {
      break;
    }

    var p = direction * z;
    p.z += travel;

    // Turbulence: repeatedly fold the sample point at rising frequency. This is
    // what breaks the smooth volume into filaments.
    var scale = 1.5;
    for (var k = 0; k < 5; k += 1) {
      scale /= 0.74;
      p += sin(p.yzx * scale - t * 0.9) / scale;
    }

    // Distance to a shell rather than to the axis: one tube gives two or three
    // fat ribbons, a shell threaded by the turbulence gives many thin filaments.
    let sheet = (abs(length(p.xy) - 1.15) + 0.05) / 6.0;
    z += sheet;

    // Brightness is relative to each filament's own core, not to the screen: the
    // falloff is sharpened so a strand is dark at its edges and climbs steeply
    // toward its centre. Crossings then add core to core and pull far ahead.
    let contribution = pow(1.0 / sheet, 1.32);
    density += contribution;
    // Low-frequency hue coordinate: depth plus the folded position, kept slow so
    // neighbouring pixels stay in the same colour family instead of speckling.
    hue_weighted += contribution * (z * 0.13 + p.z * 0.03);
  }

  let hue = (hue_weighted / max(density, 0.0001)) * 2.4 + screen.x * 0.78 + screen.y * 0.30 + t * 0.06;
  var energy = ramp(hue) * density * 0.0026;
  energy *= 1.0 + pointer_falloff * 1.35;

  // Body copy sits in the centred content column, so damp the field there. This
  // is the difference between a full-screen art piece and a background that text
  // has to survive on top of.
  // The content shell spans most of the width, so the guard has to reach past the
  // centre rather than only protecting a narrow column.
  let column = 1.0 - 0.80 * (1.0 - smoothstep(0.10, 1.05, abs(screen.x)));
  energy *= mix(0.42, 1.0, column);

  // Edges go fully dark and the field lifts only gradually inward. This is a
  // frame, not a spotlight: driving the centre hard puts the brightest part of
  // the field behind the headline, which is what the earlier pooling did wrong.
  let vignette = smoothstep(1.05, 0.05, length(screen * vec2f(0.85, 1.0)));
  energy *= 0.015 + pow(vignette, 1.35) * 0.60;

  // Tone mapped well down so the field stays a background rather than a subject.
  let base = tanh(energy * 0.033);

  let pixel = floor(uv * ambient.viewport);
  let grain = hash21(pixel + floor(ambient.time * 5.0)) - 0.5;
  let dithered = max(base + grain * 0.0016, vec3f(0.0));

  return vec4f(pow(dithered, vec3f(1.0 / 2.2)), 1.0);
}
