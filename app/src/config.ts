import { hostname } from 'node:os';

export function readConfig(env: NodeJS.ProcessEnv = process.env) {
  const port = Number(env.PORT ?? '3000');
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT must be an integer from 1 to 65535');
  }

  return {
    port,
    release: {
      application: 'clouddeploy',
      version: env.APP_VERSION || '1.0.0',
      commit: env.APP_COMMIT || 'local',
      environment: env.APP_ENV || 'local',
      instance: env.INSTANCE_NAME || hostname(),
    },
  };
}

export type Config = ReturnType<typeof readConfig>;
