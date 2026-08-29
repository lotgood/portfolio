struct HeroParams {
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
var<uniform> hero: HeroParams;

fn hash21(p: vec2f) -> f32 {
  let h = dot(p, vec2f(127.1, 311.7));
  return fract(sin(h) * 43758.5453123);
}

fn hash22(p: vec2f) -> vec2f {
  let x = dot(p, vec2f(127.1, 311.7));
  let y = dot(p, vec2f(269.5, 183.3));
  return fract(sin(vec2f(x, y)) * 43758.5453123);
}

fn value_noise(p: vec2f) -> f32 {
  let cell = floor(p);
  let local = fract(p);
  let curve = local * local * (3.0 - 2.0 * local);

  let a = hash21(cell);
  let b = hash21(cell + vec2f(1.0, 0.0));
  let c = hash21(cell + vec2f(0.0, 1.0));
  let d = hash21(cell + vec2f(1.0, 1.0));

  return mix(mix(a, b, curve.x), mix(c, d, curve.x), curve.y);
}

fn palette(t: f32) -> vec3f {
  let base = vec3f(0.08, 0.10, 0.16);
  let amplitude = vec3f(0.34, 0.28, 0.48);
  let phase = vec3f(0.13, 0.31, 0.54);
  return base + amplitude * (0.5 + 0.5 * cos(6.2831853 * (t + phase)));
}

fn rotate(p: vec2f, angle: f32) -> vec2f {
  let c = cos(angle);
  let s = sin(angle);
  return vec2f(c * p.x - s * p.y, s * p.x + c * p.y);
}

fn aces_tonemap(color: vec3f) -> vec3f {
  let a = 2.51;
  let b = 0.03;
  let c = 2.43;
  let d = 0.59;
  let e = 0.14;
  return clamp((color * (a * color + b)) / (color * (c * color + d) + e), vec3f(0.0), vec3f(1.0));
}

// Extended-range mapping: identity at or below SDR white (1.0), rational rolloff
// above it toward `limit`, so the base image matches SDR exactly and only genuine
// highlight energy rises above reference white without hard-clipping.
fn hdr_extend(color: vec3f, limit: f32) -> vec3f {
  let excess = max(color - vec3f(1.0), vec3f(0.0));
  let span = max(limit - 1.0, 0.001);
  let rolled = vec3f(span) * excess / (excess + vec3f(span));
  return min(color, vec3f(1.0)) + rolled;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  var p = (uv - 0.5) * vec2f(hero.aspect, 1.0);
  let pointer = (hero.pointer - 0.5) * vec2f(hero.aspect, 1.0);
  let time = hero.time * 0.12;

  p += pointer * 0.055;
  p.y += hero.scroll * 0.11;

  let vertical = clamp(uv.y, 0.0, 1.0);
  var color = mix(vec3f(0.003, 0.005, 0.010), vec3f(0.018, 0.024, 0.050), 1.0 - vertical);

  let atmosphere = exp(-3.1 * length(p - vec2f(0.24, -0.05)));
  color += vec3f(0.05, 0.10, 0.24) * atmosphere;

  let layers = select(2.0, select(3.0, 4.0, hero.quality > 0.88), hero.quality > 0.62);
  var q = p;
  // Highlight energy accumulated separately; in HDR mode it is lifted above SDR white.
  var glow = vec3f(0.0);

  for (var i = 0; i < 4; i += 1) {
    let layer = f32(i);
    if (layer >= layers) {
      continue;
    }

    let drift = value_noise(q * (1.65 + layer * 0.31) + vec2f(time * 0.42, layer * 7.3));
    let wave = sin(q.x * (2.35 + layer * 0.42) - time * (0.72 + layer * 0.07) + drift * 2.7);
    let offset = (layer - 1.4) * 0.105;
    let distance_to_ribbon = abs(q.y - offset - wave * (0.105 - layer * 0.009));
    let core = 0.0065 / max(distance_to_ribbon, 0.0065);
    let haze = exp(-distance_to_ribbon * (17.0 + layer * 3.0));
    let tint = palette(layer * 0.17 + time * 0.025 + q.x * 0.035);

    color += tint * (core * 0.052 + haze * 0.115);
    glow += tint * core * 0.16;
    q = rotate(q * 1.13 + vec2f(0.045, -0.025), 0.17 + layer * 0.035);
  }

  if (hero.quality > 0.62) {
    let star_grid = floor(uv * hero.viewport / 3.0);
    let star_seed = hash22(star_grid);
    let star_gate = step(0.9965, star_seed.x);
    let shimmer = 0.55 + 0.45 * sin(time * 5.0 + star_seed.y * 18.0);
    let star_color = vec3f(0.38, 0.48, 0.75) * star_gate * shimmer * 0.24;
    color += star_color;
    glow += star_color;
  }

  let horizon_wave = sin(p.x * 1.85 + time * 0.7) * 0.055;
  let horizon = exp(-24.0 * abs(p.y + 0.16 + horizon_wave));
  color += vec3f(0.11, 0.17, 0.33) * horizon * 0.16;

  let vignette = smoothstep(0.94, 0.24, length((uv - 0.5) * vec2f(0.82, 1.0)));
  let vignette_gain = 0.44 + vignette * 0.76;
  color *= vignette_gain;
  glow *= vignette_gain;

  let pixel = floor(uv * hero.viewport);
  let grain = hash21(pixel + floor(hero.time * 24.0)) - 0.5;
  color += grain * 0.005;

  let scene = max(color, vec3f(0.0)) * 1.18;
  let mapped = aces_tonemap(scene);

  if (hero.hdr_mode > 0.5) {
    // Extended-range output on the rgba16float + toneMapping 'extended' canvas:
    // the ACES base stays identical to SDR, and highlight glow is added on top so
    // star and ribbon cores land above reference white before the headroom rolloff.
    let limit = max(hero.headroom, 1.2);
    let boosted = mapped + glow * (2.2 + limit * 2.0);
    let limited = hdr_extend(boosted, limit);
    let encoded = pow(limited, vec3f(1.0 / 2.2));
    return vec4f(encoded, 1.0);
  }

  let display = pow(mapped, vec3f(1.0 / 2.2));
  return vec4f(display, 1.0);
}
