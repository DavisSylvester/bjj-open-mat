import { OpenMatRepository } from "./repositories/open-mat.repository.mts";
import { OpenMatService } from "./services/open-mat.service.mts";

// Composition root. The only place that constructs concrete instances;
// services and routes receive their dependencies from here.
export interface Container {
  readonly openMatService: OpenMatService;
}

export function createContainer(): Container {
  const openMatRepository = new OpenMatRepository();
  const openMatService = new OpenMatService(openMatRepository);
  return { openMatService };
}
