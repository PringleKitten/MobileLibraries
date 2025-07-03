package;

import grig.audio.FFT;
import grig.audio.FFTVisualization;
import tink.unit.Assert.*;

@:asserts
@:access(grig.audio.FFT)
@:access(grig.audio.FFTVisualization)
class FFTVisualizationTest
{
    private static final delta = 0.001; // this might be too forgiving

    public function new() {
    }

    public function testBands() {
        var bands = 10;
        var xscale = FFTVisualization.computeLogXScale(bands);
        asserts.assert(Math.abs(xscale[3] - 4.77803) < delta);
        asserts.assert(Math.abs(xscale[7] - 48.0029) < delta);

        var fft = new FFT(512);

        var signal = new Array<Float>();
        signal.resize(fft.n);

        for (i in 0...Std.int(signal.length / 2))
            signal[i] = i * 2.0 / signal.length;

        for (i in Std.int(signal.length / 2)...signal.length)
            signal[i] = 1.0 - (i - signal.length / 2) * 2.0 / signal.length;

        var freqs = fft.calcFreq(signal);
        var freqBandA = FFTVisualization.computeFreqBand(freqs, xscale, 3, bands);
        var freqBandB = FFTVisualization.computeFreqBand(freqs, xscale, 8, bands);
        asserts.assert(Math.abs(freqBandA - -31.6492) < delta);
        asserts.assert(Math.abs(freqBandB - -54.6572) < delta);

        var vis = new FFTVisualization();
        var bars = vis.makeLogGraph(freqs, 10, 40, 8);
        asserts.assert(bars[1] == 4);
        asserts.assert(bars[3] == 1);

        return asserts.done();
    }
}