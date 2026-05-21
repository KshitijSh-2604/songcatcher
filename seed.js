const https = require('https');

const SPOTIFY_CLIENT_ID     = 'SPOTIFY_CLIENT_ID';
const SPOTIFY_CLIENT_SECRET = 'SPOTIFY_CLIENT_SECRET';
const FIREBASE_PROJECT_ID   = 'songcatcher-fcf35';
const FIREBASE_API_KEY      = 'FIREBASE_API_KEY';

// ── Simple keyword searches — no genre: filter (deprecated by Spotify 2024) ─
const SEARCHES = [
  // Pop
  { q: 'top hits 2024',          language: 'English', genre: 'Pop' },
  { q: 'top hits 2023',          language: 'English', genre: 'Pop' },
  { q: 'top hits 2022',          language: 'English', genre: 'Pop' },
  { q: 'top hits 2021',          language: 'English', genre: 'Pop' },
  { q: 'top hits 2020',          language: 'English', genre: 'Pop' },
  { q: 'pop hits 2018 2019',     language: 'English', genre: 'Pop' },
  { q: 'pop hits 2015 2016 2017',language: 'English', genre: 'Pop' },
  { q: 'pop hits 2010 2011 2012',language: 'English', genre: 'Pop' },
  { q: 'pop hits 2000s',         language: 'English', genre: 'Pop' },
  { q: 'pop hits 1990s',         language: 'English', genre: 'Pop' },
  { q: 'pop hits 1980s',         language: 'English', genre: 'Pop' },

  // Hip-Hop / Rap
  { q: 'rap hits 2024',          language: 'English', genre: 'Hip-Hop' },
  { q: 'rap hits 2022 2023',     language: 'English', genre: 'Hip-Hop' },
  { q: 'hip hop hits 2020 2021', language: 'English', genre: 'Hip-Hop' },
  { q: 'hip hop hits 2018 2019', language: 'English', genre: 'Hip-Hop' },
  { q: 'rap hits 2015 2016 2017',language: 'English', genre: 'Hip-Hop' },
  { q: 'hip hop 2010 2011 2012', language: 'English', genre: 'Hip-Hop' },
  { q: 'rap classics 2000s',     language: 'English', genre: 'Hip-Hop' },
  { q: 'rap classics 1990s',     language: 'English', genre: 'Hip-Hop' },

  // Rock
  { q: 'rock hits 2020s',        language: 'English', genre: 'Rock' },
  { q: 'rock hits 2010s',        language: 'English', genre: 'Rock' },
  { q: 'rock hits 2000s',        language: 'English', genre: 'Rock' },
  { q: 'rock classics 1990s',    language: 'English', genre: 'Rock' },
  { q: 'rock classics 1980s',    language: 'English', genre: 'Rock' },
  { q: 'rock classics 1970s',    language: 'English', genre: 'Rock' },

  // R&B / Soul
  { q: 'rnb hits 2022 2023 2024',language: 'English', genre: 'R&B' },
  { q: 'rnb hits 2018 2019 2020',language: 'English', genre: 'R&B' },
  { q: 'rnb hits 2015 2016 2017',language: 'English', genre: 'R&B' },
  { q: 'rnb soul hits 2010s',    language: 'English', genre: 'R&B' },
  { q: 'soul hits 2000s',        language: 'English', genre: 'R&B' },

  // Electronic / Dance
  { q: 'edm dance hits 2022 2023 2024', language: 'English', genre: 'Electronic' },
  { q: 'edm dance hits 2018 2019 2020', language: 'English', genre: 'Electronic' },
  { q: 'electronic dance 2015 2016 2017', language: 'English', genre: 'Electronic' },
  { q: 'house music hits 2010s', language: 'English', genre: 'Electronic' },

  // Country
  { q: 'country hits 2022 2023 2024', language: 'English', genre: 'Country' },
  { q: 'country hits 2018 2019 2020', language: 'English', genre: 'Country' },
  { q: 'country hits 2010s',          language: 'English', genre: 'Country' },
  { q: 'country hits 2000s',          language: 'English', genre: 'Country' },

  // Indie / Alternative
  { q: 'indie pop hits 2022 2023 2024', language: 'English', genre: 'Indie' },
  { q: 'indie alternative 2018 2019 2020', language: 'English', genre: 'Indie' },
  { q: 'alternative indie 2015 2016 2017', language: 'English', genre: 'Indie' },

  // Metal
  { q: 'metal rock hits 2010 2020',  language: 'English', genre: 'Metal' },
  { q: 'heavy metal classics',        language: 'English', genre: 'Metal' },

  // Jazz / Blues
  { q: 'jazz classics popular',      language: 'English', genre: 'Jazz' },
  { q: 'blues classics popular',     language: 'English', genre: 'Blues' },

  // Reggae
  { q: 'reggae hits popular',        language: 'English', genre: 'Reggae' },

  // Gospel
  { q: 'gospel christian hits 2020s',language: 'English', genre: 'Gospel' },

  // K-Pop
  { q: 'kpop hits 2022 2023 2024',   language: 'Korean',  genre: 'K-Pop' },
  { q: 'kpop hits 2019 2020 2021',   language: 'Korean',  genre: 'K-Pop' },
  { q: 'kpop hits 2016 2017 2018',   language: 'Korean',  genre: 'K-Pop' },
  { q: 'kpop hits 2012 2013 2014 2015', language: 'Korean', genre: 'K-Pop' },

  // Latin / Reggaeton
  { q: 'reggaeton hits 2022 2023 2024', language: 'Spanish', genre: 'Reggaeton' },
  { q: 'reggaeton hits 2019 2020 2021', language: 'Spanish', genre: 'Reggaeton' },
  { q: 'reggaeton hits 2015 2016 2017', language: 'Spanish', genre: 'Reggaeton' },
  { q: 'latin pop hits 2022 2023 2024', language: 'Spanish', genre: 'Latin Pop' },
  { q: 'latin pop hits 2018 2019 2020', language: 'Spanish', genre: 'Latin Pop' },
  { q: 'salsa hits popular',            language: 'Spanish', genre: 'Salsa' },

  // French
  { q: 'french pop chanson hits 2020s', language: 'French', genre: 'Pop' },
  { q: 'chanson francaise classique',   language: 'French', genre: 'Chanson' },

  // Bollywood
  { q: 'bollywood hits 2022 2023 2024', language: 'Hindi', genre: 'Bollywood' },
  { q: 'bollywood hits 2018 2019 2020', language: 'Hindi', genre: 'Bollywood' },
  { q: 'bollywood hits 2015 2016 2017', language: 'Hindi', genre: 'Bollywood' },
  { q: 'bollywood hits 2010 2011 2012', language: 'Hindi', genre: 'Bollywood' },
  { q: 'bollywood classics 2000s',      language: 'Hindi', genre: 'Bollywood' },

  // J-Pop / Anime
  { q: 'jpop hits 2020 2021 2022 2023', language: 'Japanese', genre: 'J-Pop' },
  { q: 'jpop hits 2016 2017 2018 2019', language: 'Japanese', genre: 'J-Pop' },
  { q: 'anime songs popular',           language: 'Japanese', genre: 'Anime' },

  // Afrobeats
  { q: 'afrobeats hits 2022 2023 2024', language: 'English', genre: 'Afrobeats' },
  { q: 'afrobeats hits 2019 2020 2021', language: 'English', genre: 'Afrobeats' },

  // Brazilian
  { q: 'sertanejo hits 2020s',          language: 'Portuguese', genre: 'Sertanejo' },
  { q: 'funk brasileiro hits 2020s',    language: 'Portuguese', genre: 'Funk' },
  { q: 'bossa nova classic',            language: 'Portuguese', genre: 'Bossa Nova' },

  // Arabic
  { q: 'arabic pop hits 2020s',         language: 'Arabic', genre: 'Arabic Pop' },

  // Classics by decade
  { q: 'greatest hits 1960s popular',   language: 'English', genre: 'Classics' },
  { q: 'greatest hits 1970s popular',   language: 'English', genre: 'Classics' },
  { q: 'greatest hits 1980s popular',   language: 'English', genre: 'Classics' },
  { q: 'greatest hits 1990s popular',   language: 'English', genre: 'Classics' },
];

// ── Difficulty from popularity ─────────────────────────────────────────────

function getDifficulty(pop) {
  if (pop >= 75) return 'easy';
  if (pop >= 50) return 'medium';
  if (pop >= 25) return 'hard';
  return 'hardcore';
}

const DIFF_EMOJI = { easy: '🟢', medium: '🟡', hard: '🔴', hardcore: '💀' };

function decadeFromDate(d) {
  const y = parseInt((d || '2000').slice(0, 4));
  return isNaN(y) ? 'Unknown' : `${Math.floor(y / 10) * 10}s`;
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// ── HTTP ───────────────────────────────────────────────────────────────────

function httpGet(url, headers) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers }, (res) => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(d) }); }
        catch { resolve({ status: res.statusCode, body: d }); }
      });
    }).on('error', reject);
  });
}

function httpPost(url, headers, body) {
  return new Promise((resolve, reject) => {
    const data = Buffer.from(body);
    const opts = {
      method: 'POST',
      headers: { ...headers, 'Content-Length': data.length },
    };
    const req = https.request(url, opts, (res) => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(d) }); }
        catch { resolve({ status: res.statusCode, body: d }); }
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function httpPatch(url, headers, body) {
  return new Promise((resolve, reject) => {
    const data = Buffer.from(JSON.stringify(body));
    const opts = {
      method: 'PATCH',
      headers: { ...headers, 'Content-Length': data.length },
    };
    const req = https.request(url, opts, (res) => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(d) }); }
        catch { resolve({ status: res.statusCode, body: d }); }
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

// ── Spotify ────────────────────────────────────────────────────────────────

async function getSpotifyToken() {
  const creds = Buffer.from(`${SPOTIFY_CLIENT_ID}:${SPOTIFY_CLIENT_SECRET}`).toString('base64');
  const res = await httpPost(
    'https://accounts.spotify.com/api/token',
    { 'Authorization': `Basic ${creds}`, 'Content-Type': 'application/x-www-form-urlencoded' },
    'grant_type=client_credentials'
  );
  if (!res.body.access_token) {
    console.error('❌ Spotify failed:', JSON.stringify(res.body));
    process.exit(1);
  }
  return res.body.access_token;
}

async function searchTracks(token, query, offset) {
  const q   = encodeURIComponent(query);
  const url = `https://api.spotify.com/v1/search?q=${q}&type=track&limit=50&offset=${offset}&market=US`;

  const res = await httpGet(url, { 'Authorization': `Bearer ${token}` });

  if (res.status === 429) {
    const wait = ((res.body['Retry-After'] || 3) * 1000) + 500;
    process.stdout.write(`\n  ⏳ Rate limited — waiting ${wait / 1000}s...`);
    await sleep(wait);
    return searchTracks(token, query, offset);
  }
  if (res.status !== 200) {
    process.stdout.write(`\n  ⚠️  ${res.status}: ${JSON.stringify(res.body).slice(0, 80)}`);
    return [];
  }
  return (res.body.tracks?.items || []).filter(t => t?.preview_url);
}

// ── Firebase ───────────────────────────────────────────────────────────────

async function getFirebaseToken() {
  const res = await httpPost(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${FIREBASE_API_KEY}`,
    { 'Content-Type': 'application/json' },
    JSON.stringify({ returnSecureToken: true })
  );
  if (!res.body.idToken) {
    console.error('❌ Firebase failed:', JSON.stringify(res.body));
    process.exit(1);
  }
  return res.body.idToken;
}

async function writeSong(token, songId, data) {
  const fields = {};
  for (const [k, v] of Object.entries(data)) {
    if (v == null)             fields[k] = { nullValue: null };
    else if (typeof v === 'number')  fields[k] = { integerValue: String(v) };
    else                       fields[k] = { stringValue: String(v) };
  }
  const url = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents/songs/${songId}`;
  const res = await httpPatch(
    url,
    { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
    { fields }
  );
  return res.status === 200;
}

// ── Main ───────────────────────────────────────────────────────────────────

async function main() {
  console.log('🎵 SongCatcher Mega Seeder\n');

  console.log('Getting Spotify token...');
  const spotifyToken = await getSpotifyToken();
  console.log('✅ Spotify OK\n');

  console.log('Getting Firebase token...');
  const fbToken = await getFirebaseToken();
  console.log('✅ Firebase OK\n');

  let added = 0, failed = 0, noPreview = 0;
  const seen = new Set();
  const diff = { easy: 0, medium: 0, hard: 0, hardcore: 0 };

  for (const search of SEARCHES) {
    process.stdout.write(`\n🔍 ${search.language} / ${search.genre}: "${search.q}"\n`);

    for (let offset = 0; offset < 500; offset += 50) {
      const tracks = await searchTracks(spotifyToken, search.q, offset);
      if (!tracks.length) break;

      for (const track of tracks) {
        if (seen.has(track.id)) continue;
        seen.add(track.id);
        if (!track.preview_url) { noPreview++; continue; }

        const pop        = track.popularity || 0;
        const difficulty = getDifficulty(pop);
        const images     = track.album?.images || [];
        const albumArt   = (images.find(i => i.width === 640) || images[0])?.url || '';
        const year       = parseInt((track.album?.release_date || '2000').slice(0, 4)) || 0;
        diff[difficulty]++;

        const ok = await writeSong(fbToken, `spotify_${track.id}`, {
          title:         track.name,
          artist:        track.artists.map(a => a.name).join(', '),
          album:         track.album?.name || '',
          audioUrl:      track.preview_url,
          albumArtUrl:   albumArt,
          language:      search.language,
          genre:         search.genre,
          decade:        decadeFromDate(track.album?.release_date),
          year,
          popularity:    pop,
          difficulty,
          hint1:         `${search.genre} song`,
          hint2:         `Released in the ${decadeFromDate(track.album?.release_date)}`,
          hint3:         `By ${track.artists[0]?.name || 'Unknown'}`,
          silenceOffset: 0,
          spotifyId:     track.id,
        });

        if (ok) added++; else failed++;
        process.stdout.write(
          `\r   ${DIFF_EMOJI[difficulty]} Added:${added} ` +
          `[🟢${diff.easy} 🟡${diff.medium} 🔴${diff.hard} 💀${diff.hardcore}] ` +
          `❌${failed}   `
        );
      }
      await sleep(150);
    }
    await sleep(250);
  }

  console.log('\n\n══════════════════════════════════');
  console.log(`  🎵 Done!  ${added} songs added`);
  console.log('══════════════════════════════════');
  console.log(`  🟢 Easy:     ${diff.easy}`);
  console.log(`  🟡 Medium:   ${diff.medium}`);
  console.log(`  🔴 Hard:     ${diff.hard}`);
  console.log(`  💀 Hardcore: ${diff.hardcore}`);
  console.log(`  ⏭  No preview (skipped): ${noPreview}`);
  console.log('══════════════════════════════════');
  if (added > 0) {
    console.log('\n  ⚠️  Lock Firestore rules back:');
    console.log('  firebase deploy --only firestore:rules\n');
  }
}

main().catch(e => { console.error('💥', e.message); process.exit(1); });
