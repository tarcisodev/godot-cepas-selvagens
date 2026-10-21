const fs = require('fs');
const path = require('path');

const SAMPLE_RATE = 44100;

function writeWav(filename, samples, sampleRate = SAMPLE_RATE) {
    const numSamples = samples.length;
    const buffer = Buffer.alloc(44 + numSamples * 2);

    // RIFF identifier
    buffer.write('RIFF', 0);
    buffer.writeUInt32LE(36 + numSamples * 2, 4);
    buffer.write('WAVE', 8);

    // fmt subchunk
    buffer.write('fmt ', 12);
    buffer.writeUInt32LE(16, 16); // SubChunk1Size (16 for PCM)
    buffer.writeUInt16LE(1, 20);  // AudioFormat (1 for PCM)
    buffer.writeUInt16LE(1, 22);  // NumChannels (1 = Mono)
    buffer.writeUInt32LE(sampleRate, 24);
    buffer.writeUInt32LE(sampleRate * 2, 28); // ByteRate
    buffer.writeUInt16LE(2, 32);  // BlockAlign
    buffer.writeUInt16LE(16, 34); // BitsPerSample

    // data subchunk
    buffer.write('data', 36);
    buffer.writeUInt32LE(numSamples * 2, 40);

    for (let i = 0; i < numSamples; i++) {
        let s = Math.max(-1, Math.min(1, samples[i]));
        buffer.writeInt16LE(Math.floor(s * 32767), 44 + i * 2);
    }

    fs.writeFileSync(filename, buffer);
    console.log(`Generated: ${path.basename(filename)} (${(numSamples / sampleRate).toFixed(1)}s)`);
}

const outDir = path.join(__dirname, '..', 'assets', 'audio');

// 1. Vento Suave (wind_ambient.wav - 4s loop)
{
    const dur = 4.0;
    const num = Math.floor(dur * SAMPLE_RATE);
    const samples = new Float32Array(num);
    let last = 0;
    for (let i = 0; i < num; i++) {
        let t = i / SAMPLE_RATE;
        let white = Math.random() * 2 - 1;
        // Filtro passa-baixa suave para criar som de brisa
        last = last * 0.96 + white * 0.04;
        // Modulação lenta de rajada
        let gust = 0.5 + 0.5 * Math.sin(t * Math.PI * 2 * 0.25);
        let gust2 = 0.7 + 0.3 * Math.sin(t * Math.PI * 2 * 0.5 + 1.0);
        samples[i] = last * gust * gust2 * 0.7;
    }
    // Crossfade nas pontas para looping perfeito
    const fadeLen = Math.floor(0.2 * SAMPLE_RATE);
    for (let i = 0; i < fadeLen; i++) {
        let f = i / fadeLen;
        samples[i] = samples[i] * f + samples[num - fadeLen + i] * (1 - f);
    }
    writeWav(path.join(outDir, 'wind_ambient.wav'), samples);
}

// 2. Cachoeira (waterfall.wav - 4s loop)
{
    const dur = 4.0;
    const num = Math.floor(dur * SAMPLE_RATE);
    const samples = new Float32Array(num);
    let low = 0;
    let mid = 0;
    for (let i = 0; i < num; i++) {
        let t = i / SAMPLE_RATE;
        let white = Math.random() * 2 - 1;
        low = low * 0.92 + white * 0.08;
        mid = mid * 0.75 + white * 0.25;
        // Borbulhar e queda contínua
        let churn = 0.8 + 0.2 * Math.sin(t * 14.0) * Math.sin(t * 3.7);
        samples[i] = (low * 0.7 + mid * 0.3) * churn * 0.85;
    }
    const fadeLen = Math.floor(0.2 * SAMPLE_RATE);
    for (let i = 0; i < fadeLen; i++) {
        let f = i / fadeLen;
        samples[i] = samples[i] * f + samples[num - fadeLen + i] * (1 - f);
    }
    writeWav(path.join(outDir, 'waterfall.wav'), samples);
}

// 3. Fogueira Crepitante (campfire.wav - 4s loop)
{
    const dur = 4.0;
    const num = Math.floor(dur * SAMPLE_RATE);
    const samples = new Float32Array(num);
    let rumble = 0;
    for (let i = 0; i < num; i++) {
        let white = Math.random() * 2 - 1;
        rumble = rumble * 0.98 + white * 0.02;
        // Estalos aleatórios de graveto seco estalando
        let snap = 0;
        if (Math.random() < 0.00045) {
            snap = (Math.random() > 0.5 ? 1 : -1) * (0.6 + Math.random() * 0.4);
        }
        samples[i] = rumble * 0.35 + snap * 0.65;
    }
    writeWav(path.join(outDir, 'campfire.wav'), samples);
}

// 4. Canto de Pássaro (bird_chirp.wav - 1.2s)
{
    const dur = 1.2;
    const num = Math.floor(dur * SAMPLE_RATE);
    const samples = new Float32Array(num);
    for (let i = 0; i < num; i++) {
        let t = i / SAMPLE_RATE;
        if (t < 0.35) {
            // Primeiro pio ascendente
            let env = Math.sin((t / 0.35) * Math.PI);
            let freq = 2600 + Math.sin(t * 40.0) * 800;
            samples[i] = Math.sin(2 * Math.PI * freq * t) * env * 0.45;
        } else if (t > 0.45 && t < 0.95) {
            // Segundo pio melodioso
            let t2 = t - 0.45;
            let env = Math.sin((t2 / 0.5) * Math.PI);
            let freq = 3100 - t2 * 900;
            samples[i] = Math.sin(2 * Math.PI * freq * t) * env * 0.45;
        }
    }
    writeWav(path.join(outDir, 'bird_chirp.wav'), samples);
}

// 5. Coaxar de Sapo (frog_croak.wav - 0.7s)
{
    const dur = 0.7;
    const num = Math.floor(dur * SAMPLE_RATE);
    const samples = new Float32Array(num);
    for (let i = 0; i < num; i++) {
        let t = i / SAMPLE_RATE;
        if (t < 0.55) {
            let env = Math.pow(Math.sin((t / 0.55) * Math.PI), 1.5);
            // Pulso gutural de sapo (~140Hz com modulação de 30Hz)
            let base = Math.sin(2 * Math.PI * 140 * t);
            let rattle = Math.sign(Math.sin(2 * Math.PI * 32 * t));
            samples[i] = base * rattle * env * 0.55;
        }
    }
    writeWav(path.join(outDir, 'frog_croak.wav'), samples);
}

// 6. Grilos da Noite (crickets_night.wav - 3s loop)
{
    const dur = 3.0;
    const num = Math.floor(dur * SAMPLE_RATE);
    const samples = new Float32Array(num);
    for (let i = 0; i < num; i++) {
        let t = i / SAMPLE_RATE;
        // Trinados de grilo (~4800Hz ritmados)
        let pulse = Math.pow(Math.max(0, Math.sin(t * Math.PI * 2 * 3.5)), 4);
        let chirp = Math.sin(2 * Math.PI * 4600 * t) * 0.5 + Math.sin(2 * Math.PI * 5200 * t) * 0.5;
        samples[i] = chirp * pulse * 0.35;
    }
    writeWav(path.join(outDir, 'crickets_night.wav'), samples);
}

// 7. Passo na Grama (footstep_grass.wav - 0.22s)
{
    const dur = 0.22;
    const num = Math.floor(dur * SAMPLE_RATE);
    const samples = new Float32Array(num);
    let low = 0;
    for (let i = 0; i < num; i++) {
        let t = i / SAMPLE_RATE;
        let white = Math.random() * 2 - 1;
        low = low * 0.88 + white * 0.12;
        let env = Math.exp(-t * 26.0);
        samples[i] = low * env * 0.8;
    }
    writeWav(path.join(outDir, 'footstep_grass.wav'), samples);
}
