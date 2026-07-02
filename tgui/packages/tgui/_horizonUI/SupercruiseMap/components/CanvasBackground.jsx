import { DEG2RAD } from './MapUtils';

let starsCache = null;

function generateStars() {
  const stars = [];
  const count = 500;
  for (let i = 0; i < count; i++) {
    const u = Math.random();
    const v = Math.random();
    const theta = 2 * Math.PI * u;
    const phi = Math.acos(2 * v - 1);
    const x = Math.sin(phi) * Math.cos(theta);
    const y = Math.sin(phi) * Math.sin(theta);
    const z = Math.cos(phi);
    const colors = ['rgba(255, 255, 255, A)', 'rgba(200, 220, 255, A)', 'rgba(255, 230, 200, A)'];
    stars.push({
      x, y, z,
      size: Math.random() * 1.2 + 0.3,
      alpha: Math.random() * 0.5 + 0.2,
      color: colors[Math.floor(Math.random() * colors.length)],
    });
  }
  return stars;
}

export function drawStarfield(ctx, cameraYaw, cameraPitch, canvasWidth, canvasHeight) {
  if (!starsCache) {
    starsCache = generateStars();
  }

  const yawRad = cameraYaw * DEG2RAD;
  const pitchRad = cameraPitch * DEG2RAD;
  const cosY = Math.cos(yawRad);
  const sinY = Math.sin(yawRad);
  const cosP = Math.cos(pitchRad);
  const sinP = Math.sin(pitchRad);
  const cx = canvasWidth / 2;
  const cy = canvasHeight / 2;
  const scale = Math.hypot(cx, cy) * 1.2;

  for (const s of starsCache) {
    const x1 = s.x * cosY - s.y * sinY;
    const y1 = s.x * sinY + s.y * cosY;
    const z1 = s.z;
    const x2 = x1;
    const y2 = y1 * cosP - z1 * sinP;
    const z2 = y1 * sinP + z1 * cosP;
    if (y2 < 0) continue;
    const screenX = (x2 * scale) + cx;
    const screenY = (-z2 * scale) + cy;
    ctx.fillStyle = s.color.replace('A', s.alpha);
    ctx.beginPath();
    ctx.arc(screenX, screenY, s.size, 0, Math.PI * 2);
    ctx.fill();
  }
}
