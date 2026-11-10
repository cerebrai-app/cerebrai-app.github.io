<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue';

/**
 * Decorative background: a slowly drifting graph of linked "thoughts",
 * evoking a second brain's knowledge graph.
 */
interface Node {
  x: number;
  y: number;
  vx: number;
  vy: number;
  r: number;
}

const LINK_DISTANCE = 150;
const canvas = ref<HTMLCanvasElement | null>(null);

let frame = 0;
let nodes: Node[] = [];
let width = 0;
let height = 0;
let observer: ResizeObserver | undefined;
let motionQuery: MediaQueryList | undefined;

function seed(): void {
  // Density scales with area, capped so large screens stay cheap to draw.
  const count = Math.min(90, Math.max(24, Math.round((width * height) / 16000)));
  nodes = Array.from({ length: count }, () => ({
    x: Math.random() * width,
    y: Math.random() * height,
    vx: (Math.random() - 0.5) * 0.25,
    vy: (Math.random() - 0.5) * 0.25,
    r: 1 + Math.random() * 1.6,
  }));
}

function resize(): void {
  const el = canvas.value;
  if (!el) return;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  width = el.clientWidth;
  height = el.clientHeight;
  el.width = Math.round(width * dpr);
  el.height = Math.round(height * dpr);
  el.getContext('2d')?.setTransform(dpr, 0, 0, dpr, 0, 0);
  seed();
  draw();
}

function draw(): void {
  const ctx = canvas.value?.getContext('2d');
  if (!ctx) return;
  ctx.clearRect(0, 0, width, height);

  ctx.lineWidth = 1;
  nodes.forEach((a, i) => {
    for (const b of nodes.slice(i + 1)) {
      const dist = Math.hypot(a.x - b.x, a.y - b.y);
      if (dist >= LINK_DISTANCE) continue;
      ctx.strokeStyle = `rgb(139 124 255 / ${0.22 * (1 - dist / LINK_DISTANCE)})`;
      ctx.beginPath();
      ctx.moveTo(a.x, a.y);
      ctx.lineTo(b.x, b.y);
      ctx.stroke();
    }
  });

  ctx.fillStyle = 'rgb(160 220 235 / 0.7)';
  for (const n of nodes) {
    ctx.beginPath();
    ctx.arc(n.x, n.y, n.r, 0, Math.PI * 2);
    ctx.fill();
  }
}

function tick(): void {
  for (const n of nodes) {
    n.x += n.vx;
    n.y += n.vy;
    if (n.x < 0 || n.x > width) n.vx *= -1;
    if (n.y < 0 || n.y > height) n.vy *= -1;
  }
  draw();
  frame = requestAnimationFrame(tick);
}

function syncMotion(): void {
  cancelAnimationFrame(frame);
  // With reduced motion the graph stays as a still image.
  if (!motionQuery?.matches) frame = requestAnimationFrame(tick);
}

onMounted(() => {
  motionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
  motionQuery.addEventListener('change', syncMotion);
  observer = new ResizeObserver(resize);
  if (canvas.value) observer.observe(canvas.value);
  resize();
  syncMotion();
});

onBeforeUnmount(() => {
  cancelAnimationFrame(frame);
  observer?.disconnect();
  motionQuery?.removeEventListener('change', syncMotion);
});
</script>

<template>
  <canvas ref="canvas" class="field" aria-hidden="true"></canvas>
</template>

<style scoped>
.field {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  display: block;
}
</style>
