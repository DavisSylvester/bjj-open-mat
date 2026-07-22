import { google } from 'googleapis';
import { readFileSync } from 'fs';

const PACKAGE = 'com.davissylvester.bjjopenmat';
const SA_PATH = './.google-service-account.json';

const auth = new google.auth.GoogleAuth({
  keyFile: SA_PATH,
  scopes: ['https://www.googleapis.com/auth/androidpublisher'],
});

const publisher = google.androidpublisher({ version: 'v3', auth });

async function main() {
  const editRes = await publisher.edits.insert({ packageName: PACKAGE });
  const editId = editRes.data.id;
  console.log('Edit ID:', editId);

  const tracksRes = await publisher.edits.tracks.list({ packageName: PACKAGE, editId });
  console.log('\n=== All tracks ===');
  for (const track of tracksRes.data.tracks ?? []) {
    console.log(`\nTrack: ${track.track}`);
    for (const release of track.releases ?? []) {
      console.log(`  status: ${release.status}, versionCodes: ${release.versionCodes?.join(', ')}, name: ${release.name}`);
    }
  }

  // Clean up — delete the edit (read-only check, don't commit)
  await publisher.edits.delete({ packageName: PACKAGE, editId });
  console.log('\nEdit cleaned up (not committed).');
}

main().catch(err => { console.error(err.message); process.exit(1); });
