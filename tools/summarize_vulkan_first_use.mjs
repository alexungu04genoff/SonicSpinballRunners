// Read-only reporting for explicit Godot profiling runs. Uses Node's standard library.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';

const directory = process.argv[2];
if (!directory) throw new Error('Usage: node tools/summarize_vulkan_first_use.mjs <evidence-directory>');
const sum = values => values.reduce((total, value) => total + value, 0);
const median = values => values.length ? [...values].sort((a, b) => a - b)[Math.floor(values.length / 2)] : null;
const delta = (after, before) => Object.fromEntries(Object.keys(after).map(key => [key, after[key] - (before[key] ?? 0)]));
const maximum = values => values.length ? Math.max(...values) : null;
const phases = frames => Object.fromEntries([...new Set(frames.map(row => row.phase))].map(phase => {
  const rows = frames.filter(row => row.phase === phase);
  const keys = Object.keys(rows[0].delta);
  return [phase, {
    wall_ms: sum(rows.map(row => row.frame_ms)), worst_ms: Math.max(...rows.map(row => row.frame_ms)),
    median_ms: median(rows.map(row => row.frame_ms)), frames_over_100_ms: rows.filter(row => row.frame_ms > 100).length,
    render_cpu_median_ms: median(rows.map(row => row.render_cpu_ms)), render_gpu_median_ms: median(rows.map(row => row.render_gpu_ms)),
    render_wall_worst_ms: Math.max(...rows.map(row => row.render_wall_ms)),
    draw_median: median(rows.map(row => row.draws)), object_median: median(rows.map(row => row.objects)),
    resources_peak: Math.max(...rows.map(row => row.resources)),
    memory_peak_bytes: Math.max(...rows.map(row => row.memory_bytes)), video_peak_bytes: Math.max(...rows.map(row => row.video_bytes)),
    resident_peak: Math.max(...rows.map(row => row.resident_acts ?? 0)),
    pipelines: Object.fromEntries(keys.map(key => [key, sum(rows.map(row => row.delta[key]))]))
  }];
}));
const results = [];
for (const name of fs.readdirSync(directory).filter(name => name.endsWith('.json') && !name.endsWith('-process.json'))) {
  const raw = fs.readFileSync(path.join(directory, name));
  const report = JSON.parse(raw);
  if (!report.frames?.length) continue;
  const frames = report.frames;
  const worst = [...frames].sort((a, b) => b.frame_ms - a.frame_ms).slice(0, 6);
  const marks = report.marks ?? [];
  const ready = marks.find(mark => mark.name === 'first_act_ready');
  const receiptPath = path.join(directory, name.replace('.json', '-process.json'));
  const receipt = fs.existsSync(receiptPath) ? JSON.parse(fs.readFileSync(receiptPath, 'utf8')) : null;
  const shaderSources = resources => [...new Map(resources.filter(resource => resource.category === 'shaders')
    .map(resource => [resource.code_sha256 + ':' + resource.path, {path: resource.path, code_sha256: resource.code_sha256}])).values()];
  const cacheTotals = value => { const files = value ? (Array.isArray(value) ? value : [value]) : []; return {files: files.length, bytes: sum(files.map(file => file.bytes)),
    shader_files: files.filter(file => file.path.includes('shader_cache')).length,
    pipeline_files: files.filter(file => !file.path.includes('shader_cache'))}; };
  const intervals = marks.slice(1).map((mark, i) => ({
    from: marks[i].name, to: mark.name, wall_ms: (mark.at_us - marks[i].at_us) / 1000,
    pipelines: delta(mark.pipelines, marks[i].pipelines)
  }));
  results.push({file: name, sha256: createHash('sha256').update(raw).digest('hex'), metadata: report.metadata,
    ready_ms: report.ready_ms, ready_from_engine_ms: report.ready_from_engine_ms,
    success: report.success, pipelines: report.pipelines, inventory: report.inventory,
    live_inventory: report.live_inventory?.counts, live_geometry_nodes: report.live_inventory?.geometry_nodes,
    recipe_receipts: report.recipe_inventory ? Object.fromEntries(Object.entries(report.recipe_inventory).map(([key, value]) =>
      [key, {path: value.path, pipeline_fingerprint: value.pipeline_fingerprint, records: value.records, counts: value.counts}])) : undefined,
    shader_sources: report.recipe_inventory ? {
      baked: shaderSources(Object.values(report.recipe_inventory).flatMap(value => Object.values(value.resources))),
      live: shaderSources(Object.values(report.live_inventory.resources))} : undefined,
    resident_acts: report.resident_acts, rebuilds: report.rebuilds, visual_reuse: report.visual_reuse,
    quality: report.quality, world_size: report.world_size, window_size: report.window_size,
    camera: report.camera, course: report.course,
    probe: report.kind ? {kind: report.kind, attachment: report.attachment, path: report.path,
      pipeline_fingerprint: report.fingerprint, recipe_nodes: report.recipe_nodes,
      selected: report.kind === 'probes' ? report.selected : undefined,
      node_classes: Object.fromEntries([...new Set(report.selected.map(node => node.class))].sort().map(name =>
        [name, report.selected.filter(node => node.class === name).length])),
      precompile_msaa: report.precompile_msaa, viewport_msaa: report.viewport_msaa} : undefined,
    first_completion_ms: frames[0].frame_ms,
    worst_completion_after_first_ms: maximum(frames.slice(1).map(row => row.frame_ms)),
    worst_after_ready_ms: ready ? maximum(frames.filter(row => row.end_us >= ready.at_us).map(row => row.frame_ms)) : undefined,
    first_visible_frame: frames.find(row => row.started),
    cache: receipt ? {condition: receipt.condition, seed_profile: receipt.seed_profile, seed_cache: receipt.seed_cache,
      verbose_engine: receipt.arguments.includes('--verbose'),
      before: cacheTotals(receipt.before), after: cacheTotals(receipt.after),
      other_godot_processes: receipt.other_renderer_processes, process_wall_ms: receipt.process_wall_ms,
      engine_sha256: receipt.engine_sha256, driver_cache: receipt.driver_cache} : undefined,
    phases: phases(frames), stages: frames.some(row => row.stage) ? phases(frames.map(row => ({...row, phase: row.stage ?? row.phase}))) : undefined, marks, intervals,
    worst: worst.map(row => ({...row, events: (report.events ?? []).filter(event => event.start_us < row.end_us && event.end_us > row.start_us)}))});
}
process.stdout.write(JSON.stringify(results, null, 2) + '\n');
