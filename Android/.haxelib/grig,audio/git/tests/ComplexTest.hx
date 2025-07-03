package;

import grig.audio.Complex;
import tink.unit.Assert.*;

@:asserts
class ComplexTest
{
    private static final delta = 0.0001;

    public function new() {
    }

    public function testAdd() {
        // create a Complex number
        var a = new Complex(3, 4);

        // create another one
        var b = new Complex(1, 2);

        // perform sum
        var c = a + b;
        asserts.assert(c == new Complex(4, 6));

        // doing some calculation
        var n = Complex.exp(Complex.sqrt((a + b)) * Complex.fromPolar(2.0, Math.PI / 2));
        asserts.assert(Math.abs(n.real - 0.00109563422690663482) < delta);
        asserts.assert(Math.abs(n.imag - 0.000164828383398954621) < delta);

        // get the abs value
        var r = Complex.abs(a);
        asserts.assert(r == 5);

        // compute the pow of a Complex number
        var p = Complex.pow(new Complex(4, 5), 7.2);
        asserts.assert(Math.abs(p.real - 630715.610159980832) < delta);
        asserts.assert(Math.abs(p.imag - 107236.777142219638) < delta);

        // compute the log e of complex Number
        var l = Complex.log(new Complex(2, 3));
        asserts.assert(Math.abs(l.real - 1.28247467873076837) < delta);
        asserts.assert(Math.abs(l.imag - 0.982793723247329) < delta);

        return asserts.done();
    }
}