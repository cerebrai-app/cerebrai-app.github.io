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
  const widthChanged = el.clientWidth !== width;
  width = el.clientWidth;
  height = el.clientHeight;
  el.width = Math.round(width * dpr);
  el.height = Math.round(height * dpr);
  el.getContext('2d')?.setTransform(dpr, 0, 0, dpr, 0, 0);
  // Phones show and hide the address bar while scrolling, which only changes the
  // height. Keep the graph in that case instead of reshuffling it mid-scroll.
  if (widthChanged || nodes.length === 0) seed();
  draw();
}

function draw(): void {
  const ctx = canvas.value?.getContext('2d');
  if (!ctx) return;
  ctx.clearRect(0, 0, width, height);

  ctx.lineWidth = 1;
  for (let i = 0; i < nodes.length; i++) {
    const a = nodes[i];
    if (!a) continue;
    for (let j = i + 1; j < nodes.length; j++) {
      const b = nodes[j];
      if (!b) continue;
      const dist = Math.hypot(a.x - b.x, a.y - b.y);
      if (dist >= LINK_DISTANCE) continue;
      ctx.strokeStyle = `rgb(139 124 255 / ${0.22 * (1 - dist / LINK_DISTANCE)})`;
      ctx.beginPath();
      ctx.moveTo(a.x, a.y);
      ctx.lineTo(b.x, b.y);
      ctx.stroke();
    }
  }

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
    // Point the velocity inward rather than flipping it, so a node left outside by a
    // shrinking canvas heads back in instead of jittering on the edge.
    if (n.x < 0) n.vx = Math.abs(n.vx);
    else if (n.x > width) n.vx = -Math.abs(n.vx);
    if (n.y < 0) n.vy = Math.abs(n.vy);
    else if (n.y > height) n.vy = -Math.abs(n.vy);
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
