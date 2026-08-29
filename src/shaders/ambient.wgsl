// Document-level ambient field for everything outside the hero.
//
// Volumetric march through a turbulent field: each step folds the sample point
// with a sin-based turbulence, then accumulates light divided by the distance to
// the folded sheet. That accumulation is what produces thin white-hot cores with
// coloured halos - and it produces far more range than SDR can show, which is
// exactly the point. `base` is the tone-mapped image an SDR display gets; `glow`
// is the energy tone mapping had to compress away, and the HDR path puts it back
// above reference white.
//
// The pointer steers the ray and adds a local attractor, so the field answers the
// cursor. Scroll travels forward through the volume.
//
// Original work. FragCoord/@Xor shaders informed the technique family only; no
// third-party shader source is included (see docs/SHADER_PORTING.md).

struct AmbientParams {
  time: f32,
  aspect: f32,
  scroll: f32,
  quality: f32,
  hdr_mode: f32,
  headroom: f32,
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

// Identity at or below reference white, soft knee above it toward `limit`.
fn hdr_extend(color: vec3f, limit: f32) -> vec3f {
  let excess = max(color - vec3f(1.0), vec3f(0.0));
  let span = max(limit - 1.0, 0.001);
  let rolled = vec3f(span) * (vec3f(1.0) - exp(-excess / vec3f(span)));
  return min(color, vec3f(1.0)) + rolled;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let screen = (uv - 0.5) * vec2f(ambient.aspect, 1.0);
  let t = ambient.time * 0.16;
  // Scroll nudges the field forward. Deep travel per scroll unit makes the whole
  // volume churn while scrolling, which reads as motion sickness rather than
  // parallax, so the coupling stays small.
  let travel = ambient.time * 0.10 + ambient.scroll * 0.85;

  let steps = select(8, select(12, 16, ambient.quality > 0.88), ambient.quality > 0.62);

  // Pointer steers the ray and pulls a brighter knot toward the cursor.
  let pointer = (ambient.pointer - 0.5) * vec2f(ambient.aspect, 1.0);
  let to_pointer = screen - pointer;
  let pointer_falloff = exp(-length(to_pointer) * 2.2);

  var direction = normalize(vec3f(screen * 1.15, 1.0));
  direction = normalize(direction + vec3f(pointer * 0.22, 0.0));



  // Per-pixel jitter on the march start. Without it, a 16-step march quantises
  // into visible shells that crawl across the screen as the field moves.
  let jitter = hash21(floor(uv * ambient.viewport) + floor(ambient.time * 60.0) * 0.017);
  var z = 0.55 + jitter * 0.045;
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
    let contribution = pow(1.0 / sheet, 1.45);
    density += contribution;
    // Low-frequency hue coordinate: depth plus the folded position, kept slow so
    // neighbouring pixels stay in the same colour family instead of speckling.
    hue_weighted += contribution * (z * 0.13 + p.z * 0.03);
  }

  let hue = (hue_weighted / max(density, 0.0001)) * 2.4 + screen.x * 0.78 + screen.y * 0.30 + t * 0.06;
  var energy = ramp(hue) * density * 0.0010;
  energy *= 1.0 + pointer_falloff * 1.35;

  // Body copy sits in the centred content column, so damp the field there. This
  // is the difference between a full-screen art piece and a background that text
  // has to survive on top of.
  // The content shell spans most of the width, so the guard has to reach past the
  // centre rather than only protecting a narrow column.
  let column = 1.0 - 0.80 * (1.0 - smoothstep(0.10, 1.05, abs(screen.x)));
  energy *= mix(0.42, 1.0, column);

  // Only a gentle frame vignette. Pooling brightness at the screen centre put the
  // hottest part of the field directly behind the headline; the dark-to-bright
  // gradient belongs to each filament instead.
  let vignette = smoothstep(1.25, 0.35, length(screen * vec2f(0.85, 1.0)));
  energy *= 0.55 + vignette * 0.55;

  // `base` is what an SDR display can show, deliberately tone mapped well down so
  // the field stays a background. `spill` is the range that compression discards,
  // and it is measured from the uncompressed energy, not from the mapped image -
  // that separation is what lets SDR stay calm while HDR still gets hot cores.
  // Rarer but hotter cores: a wide band sitting just over white washes out body
  // copy, while a small number of genuinely bright cores reads as HDR.
  let base = tanh(energy * 0.033);

  // Overbright is measured on luminance, not per channel, then re-tinted with the
  // local colour. Thresholding each channel separately would let whichever
  // channel is strongest spill alone, turning every highlight the same hue.
  // Threshold on the strongest channel, which is hue-neutral, then re-tint with
  // the pixel's own colour.
  //
  // Thresholding on luminance looks natural but weights green at 0.72, so
  // green-leaning pixels cross first and every core comes out green. Thresholding
  // per channel has the mirror problem: whichever channel the palette favours
  // spills alone. Only a hue-neutral magnitude keeps colour out of the decision.
  let peak = max(max(energy.r, energy.g), max(energy.b, 0.0001));
  // Mildly superlinear, so crossings pull ahead of single passes without running
  // away. A steep exponent amplifies the march's dither into visible speckle,
  // because the noise is multiplied along with the signal.
  let overlap = pow(peak, 1.25);
  let spill = (energy / peak) * max(overlap - 7.0, 0.0) * 1.5;

  let pixel = floor(uv * ambient.viewport);
  let grain = hash21(pixel + floor(ambient.time * 20.0)) - 0.5;
  let dithered = max(base + grain * 0.004, vec3f(0.0));

  if (ambient.hdr_mode > 0.5) {
    let limit = max(ambient.headroom, 1.2);
    let boosted = dithered + spill;
    return vec4f(pow(hdr_extend(boosted, limit), vec3f(1.0 / 2.2)), 1.0);
  }

  return vec4f(pow(dithered, vec3f(1.0 / 2.2)), 1.0);
}
