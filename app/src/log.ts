export function log(level: 'info' | 'error', event: string, fields: Record<string, unknown> = {}) {
  const line = JSON.stringify({ timestamp: new Date().toISOString(), level, event, ...fields });
  const stream = level === 'error' ? process.stderr : process.stdout;
  stream.write(line + '\n');
}
