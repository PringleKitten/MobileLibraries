package;

using grig.audio.lime.AudioBufferTools;
import tink.unit.Assert.*;

@:asserts
class LimeUtilsTest
{
    private static final delta = 0.000001;

    public function new() {
    }

#if lime
    public function testConvert() {
        var bytes = haxe.Resource.getBytes("tests/tri.ogg");
        var audioBuffer = lime.media.AudioBuffer.fromBytes(bytes);
        var audioSamples = audioBuffer.toInterleaved();
        asserts.assert(audioSamples.length == 191688);
        asserts.assert(Math.abs(audioSamples[4000] - -0.0719626453444014) < delta);

        return asserts.done();
    }
#end
}