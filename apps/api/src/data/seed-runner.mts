import { loadEnv } from "../config/env.mts";
import { logger } from "../config/logger.mts";
import { createMongoContext } from "../db/mongo.mts";
import { GymRepository } from "../repositories/gym.repository.mts";
import { OpenMatRepository } from "../repositories/open-mat.repository.mts";
import { RsvpRepository } from "../repositories/rsvp.repository.mts";
import { UserRepository } from "../repositories/user.repository.mts";
import { seedAttendees, seedOpenMats } from "./seed.mts";

const env = loadEnv();
const { client, db } = createMongoContext(env);
await client.connect();

const gymRepo = new GymRepository(db);
const matRepo = new OpenMatRepository(db);
const rsvpRepo = new RsvpRepository(db);
const userRepo = new UserRepository(db);

await Promise.all([gymRepo.ensureIndexes(), matRepo.ensureIndexes(), rsvpRepo.ensureIndexes(), userRepo.ensureIndexes()]);

for (const mat of seedOpenMats) {
  await gymRepo
    .insert({
      id: mat.gymId,
      ownerId: env.demoUser.id,
      name: mat.gymName ?? mat.gymId,
      address: mat.address,
      city: mat.city,
      state: mat.state,
      postalCode: mat.postalCode,
      location:
        mat.latitude !== undefined && mat.longitude !== undefined
          ? { lat: mat.latitude, lng: mat.longitude }
          : undefined,
      amenities: [],
      isVerified: true,
      rating: mat.gymRating,
    })
    .catch(() => undefined);
  await matRepo.insert(mat, env.demoUser.id).catch(() => undefined);
}

for (const [openMatId, attendees] of Object.entries(seedAttendees)) {
  for (const a of attendees) {
    await userRepo
      .insert({
        id: a.userId,
        email: `${a.userId}@seed.dev`,
        displayName: a.name,
        role: "practitioner",
        beltRank: a.beltRank,
        beltStripes: a.beltStripes,
      })
      .catch(() => undefined);
    await rsvpRepo.add(openMatId, "2026-06-20", a.userId).catch(() => undefined);
  }
}

logger.info(`Seeded ${seedOpenMats.length} gyms + open mats`);
await client.close();
