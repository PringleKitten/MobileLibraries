package;
  
import tink.testrunner.*;
import tink.unit.*;

class RunTests {

    static function main()
    {
        Runner.run(TestBatch.make([
            new AudioChannelTest(),
            new ComplexTest(),
            new FFTTest(),
            new FFTVisualizationTest(),
        ])).handle(Runner.exit);
    }

}