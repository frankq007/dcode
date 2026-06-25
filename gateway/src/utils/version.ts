export function isVersionCompatible(local: string, remote: string): { compatible: boolean; warning: string | null } {
  const [lMaj, lMin] = local.split('.').map(Number);
  const [rMaj, rMin] = remote.split('.').map(Number);
  if (lMaj !== rMaj) return { compatible: false, warning: null };
  if (lMin !== rMin) return { compatible: true, warning: `Version minor mismatch: ${local} vs ${remote}` };
  return { compatible: true, warning: null };
}
