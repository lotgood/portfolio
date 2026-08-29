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
  var z = 0.55 + jitter * 0.12;
  var accumulated = vec3f(0.0);

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

    // Iridescence: hue advances with depth and with the turbulence itself, so
    // neighbouring filaments separate into cyan, violet and warm gold instead of
    // one flat blue. The base stays cool; the accents ride on the hot cores.
    let hue = z * 1.15 + p.z * 0.12 + t * 0.35;
    let tint = vec3f(0.30, 0.36, 0.56) + vec3f(0.32, 0.20, 0.26) * cos(vec3f(0.0, 2.1, 4.2) + hue);
    accumulated += tint / sheet;
  }

  var energy = accumulated * 0.0060;
  energy *= 1.0 + pointer_falloff * 1.35;

  // Body copy sits in the centred content column, so damp the field there. This
  // is the difference between a full-screen art piece and a background that text
  // has to survive on top of.
  // The content shell spans most of the width, so the guard has to reach past the
  // centre rather than only protecting a narrow column.
  let column = 1.0 - 0.80 * (1.0 - smoothstep(0.10, 1.05, abs(screen.x)));
  energy *= mix(0.42, 1.0, column);

  let vignette = smoothstep(1.08, 0.22, length(screen * vec2f(0.82, 1.0)));
  energy *= 0.26 + vignette * 0.62;

  // `base` is what an SDR display can show, deliberately tone mapped well down so
  // the field stays a background. `spill` is the range that compression discards,
  // and it is measured from the uncompressed energy, not from the mapped image -
  // that separation is what lets SDR stay calm while HDR still gets hot cores.
  // Rarer but hotter cores: a wide band sitting just over white washes out body
  // copy, while a small number of genuinely bright cores reads as HDR.
  let base = tanh(energy * 0.033);
  let spill = max(energy - 3.2, vec3f(0.0)) * 1.9;

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
