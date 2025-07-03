package;
  
import tink.testrunner.*;
import tink.unit.*;

class RunLimeTests extends lime.app.Application {

    public function new()
    {
        super();
        Runner.run(TestBatch.make([
            new LimeUtilsTest(),
        ])).handle(Runner.exit);
    }

}