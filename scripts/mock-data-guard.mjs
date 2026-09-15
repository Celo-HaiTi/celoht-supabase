import fs from 'node:fs';
import path from 'node:path';

const repoRoot = process.cwd();
const skipDirs = new Set(['.git', 'node_modules', '.next', 'dist', 'build', 'coverage', '.turbo', '.supabase', '.venv']);
const prohibitedPatterns = [
  '__mocks__',
  'mock-data',
  'mock_data',
  'mockdata',
  'fixtures',
  'fixture',
  'demo-data',
  'demo_data',
  'fake-data',
  'fake_data',
  'seed-data',
  'seed_data',
];

const filesToScan = [];

function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.')) {
      if (entry.name === '.github' || entry.name === '.vscode') continue;
    }
    if (entry.isDirectory()) {
      if (skipDirs.has(entry.name)) continue;
      walk(path.join(dir, entry.name));
      continue;
    }
    if (/\.(?:[cm]?jsx?|[cm]?tsx?|mjs|cjs)$/i.test(entry.name)) {
      filesToScan.push(path.join(dir, entry.name));
    }
  }
}

walk(repoRoot);

const violations = [];

for (const file of filesToScan) {
  const relative = path.relative(repoRoot, file).split(path.sep).join('/');
  const source = fs.readFileSync(file, 'utf8');
  const matches = new Set();

  const specifiers = [...source.matchAll(/(?:import|export)\s+(?:[^'"`]*?\s+from\s+)?['"`]([^'"`]+)['"`]|require\(\s*['"`]([^'"`]+)['"`]\s*\)/g)];

  for (const match of specifiers) {
    const candidate = (match[1] || match[2] || '').trim();
    if (!candidate) continue;
    const lower = candidate.toLowerCase();
    if (prohibitedPatterns.some((pattern) => lower.includes(pattern.toLowerCase()))) {
      matches.add(candidate);
    }
  }

  if (matches.size > 0) {
    for (const specifier of [...matches].sort()) {
      violations.push(`${relative}: ${specifier}`);
    }
  }
}

if (violations.length > 0) {
  console.error('Prohibited mock-data imports detected:');
  for (const violation of violations) {
    console.error(`- ${violation}`);
  }
  process.exit(1);
}

console.log('No prohibited mock-data imports found.');
