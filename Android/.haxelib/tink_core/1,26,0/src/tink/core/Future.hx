package tink.core;

using tink.CoreApi;

#if js
import #if haxe4 js.lib.Error #else js.Error #end as JsError;
import #if haxe4 js.lib.Promise #else js.Promise #end as JsPromise;
#end

@:forward(handle, gather, eager)
abstract Future<T>(FutureObject<T>) from FutureObject<T> to FutureObject<T> {
  
  public static var NULL:Future<Dynamic> = Future.sync(null);
  public static var NOISE:Future<Noise> = Future.sync(Noise);
  public static var NEVER:Future<Dynamic> = (NeverFuture.inst:FutureObject<Dynamic>);

  public inline function new(f:Callback<T>->CallbackLink) 
    this = new SuspendableFuture(f);  
  
  /**
   *  Creates a future that contains the first result from `this` or `other`
   */
  public function first(other:Future<T>):Future<T> { // <-- consider making it lazy by default ... also pull down into FutureObject
    var ret = Future.trigger();
    var l1 = this.handle(ret.trigger);
    var l2 = other.handle(ret.trigger);
    var ret = ret.asFuture();
    if (l1 != null)
      ret.handle(l1);
    if (l2 != null)
      ret.handle(l2);
    return ret;
  }
  
  /**
   *  Creates a new future by applying a transform function to the result.
   *  Different from `flatMap`, the transform function of `map` returns a sync value
   */
  public inline function map<A>(f:T->A, ?gather = true):Future<A> {
    var ret = this.map(f);
    return
      if (gather) ret.gather();
      else ret;
  }
  
  /**
   *  Creates a new future by applying a transform function to the result.
   *  Different from `map`, the transform function of `flatMap` returns a `Future`
   */
  public inline function flatMap<A>(next:T->Future<A>, ?gather = true):Future<A> {
    var ret = this.flatMap(next);
    return
      if (gather) ret.gather();
      else ret;    
  }  
  
  /**
   *  Like `map` and `flatMap` but with a polymorphic transformer and return a `Promise`
   *  @see `Next`
   */
  public function next<R>(n:Next<T, R>):Promise<R>
    return this.flatMap(function (v) return n(v));
  
  /**
   *  Merges two futures into one by applying the merger function on the two future values
   */
  public function merge<A, R>(other:Future<A>, merger:T->A->R, ?gather = true):Future<R> 
    return flatMap(function (t:T) {
      return other.map(function (a:A) return merger(t, a), false);
    }, gather);
  
  /**
   *  Flattens `Future<Future<A>>` into `Future<A>`
   */
  static public function flatten<A>(f:Future<Future<A>>):Future<A> 
    return new SuspendableFuture<A>(function (yield) {
      var inner = null;
      var outer = f.handle(function (second) {
        inner = second.handle(yield);
      });
      return outer.join(function () inner.dissolve());
    });
  
  #if js
  /**
   *  Casts a js Promise into a Surprise
   */
  @:from static public function ofJsPromise<A>(promise:JsPromise<A>):Surprise<A, Error>
    return Future.async(function(cb) promise.then(function(a) cb(Success(a))).catchError(function(e:JsError) cb(Failure(Error.withData(e.message, e)))));
  #end
  
  @:from static inline function ofAny<T>(v:T):Future<T>
    return Future.sync(v);
  
  /**
   *  Casts a Surprise into a Promise
   */
  static inline public function asPromise<T>(s:Surprise<T, Error>):Promise<T>
    return s;
  
  /**
   *  Merges multiple futures into Future<Array<A>>
   */
  static public function ofMany<A>(futures:Array<Future<A>>, ?gather:Bool = true) {
    var ret = sync([]);
    for (f in futures)
      ret = ret.flatMap(
        function (results:Array<A>) 
          return f.map(
            function (result) 
              return results.concat([result]),
            false
          ),
        false
      );
    return 
      if (gather) ret.gather();
      else ret;
  }
  
  @:deprecated('Implicit cast from Array<Future> is deprecated, please use `ofMany` instead. Please create an issue if you find it useful, and don\'t want this cast removed.')
  @:from static function fromMany<A>(futures:Array<Future<A>>):Future<Array<A>> 
    return ofMany(futures);
  
  //TODO: use this as `sync` for 2.0
  @:noUsing static inline public function lazy<A>(l:Lazy<A>):Future<A>
    return new SyncFuture(l);    
  
  /**
   *  Creates a sync future.
   *  Example: `var i = Future.sync(1); // Future<Int>`
   */
  @:noUsing static inline public function sync<A>(v:A):Future<A> 
    return new SyncFuture(v); 

  @:noUsing static inline public function isFuture(maybeFuture: Dynamic)
    return Std.is(maybeFuture, FutureObject);
    
  /**
   *  Creates an async future
   *  Example: `var i = Future.async(function(cb) cb(1)); // Future<Int>`
   */
  #if python @:native('make') #end
  @:noUsing static public function async<A>(f:(A->Void)->Void, ?lazy = false):Future<A> 
    if (lazy) 
      return new SuspendableFuture(function (yield) {
        f(yield);
        return null;
      });
    else {
      var op = trigger();
      var wrapped:Callback<A->Void> = f;
      wrapped.invoke(op.trigger);
      return op;      
    }    
    
  /**
   *  Same as `first`
   */
  @:noCompletion @:op(a || b) static public function or<A>(a:Future<A>, b:Future<A>):Future<A>
    return a.first(b);
    
  /**
   *  Same as `first`, but use `Either` to handle the two different types
   */
  @:noCompletion @:op(a || b) static public function either<A, B>(a:Future<A>, b:Future<B>):Future<Either<A, B>>
    return a.map(Either.Left, false).first(b.map(Either.Right, false));
      
  /**
   *  Uses `Pair` to merge two futures
   */
  @:noCompletion @:op(a && b) static public function and<A, B>(a:Future<A>, b:Future<B>):Future<Pair<A, B>>
    return a.merge(b, function (a, b) return new Pair(a, b));
  
  @:noCompletion @:op(a >> b) static public function _tryFailingFlatMap<D, F, R>(f:Surprise<D, F>, map:D->Surprise<R, F>)
    return f.flatMap(function (o) return switch o {
      case Success(d): map(d);
      case Failure(f): Future.sync(Failure(f));
    });

  @:noCompletion @:op(a >> b) static public function _tryFlatMap<D, F, R>(f:Surprise<D, F>, map:D->Future<R>):Surprise<R, F> 
    return f.flatMap(function (o) return switch o {
      case Success(d): map(d).map(Success);
      case Failure(f): Future.sync(Failure(f));
    });
    
  @:noCompletion @:op(a >> b) static public function _tryFailingMap<D, F, R>(f:Surprise<D, F>, map:D->Outcome<R, F>)
    return f.map(function (o) return o.flatMap(map));

  @:noCompletion @:op(a >> b) static public function _tryMap<D, F, R>(f:Surprise<D, F>, map:D->R)
    return f.map(function (o) return o.map(map));    
  
  @:noCompletion @:op(a >> b) static public function _flatMap<T, R>(f:Future<T>, map:T->Future<R>)
    return f.flatMap(map);

  @:noCompletion @:op(a >> b) static public function _map<T, R>(f:Future<T>, map:T->R)
    return f.map(map);

  /**
   *  Creates a new `FutureTrigger`
   */
  @:noUsing static public inline function trigger<A>():FutureTrigger<A> 
    return new FutureTrigger();  
    
  @:noUsing static public function delay<T>(ms:Int, value:Lazy<T>):Future<T>
    return Future.async(function(cb) haxe.Timer.delay(function() cb(value.get()), ms));

}

interface FutureObject<T> {

  function map<R>(f:T->R):Future<R>;
  function flatMap<R>(f:T->Future<R>):Future<R>;
  /**
   *  Registers a callback to handle the future result.
   *  If the result is already available, the callback will be invoked immediately.
   *  @return A `CallbackLink` instance that can be used to cancel the callback, no effect if the callback is already invoked 
   */
  function handle(callback:Callback<T>):CallbackLink;
  /**
   *  Caches the result to ensure the underlying tranform is performed once only.
   *  Useful for tranformed futures, such as product of `map` and `flatMap`
   *  so that the transformation function will not be invoked for every callback
   */
  function gather():Future<T>;
  /**
   *  Makes this future eager.
   *  Futures are lazy by default, i.e. it does not try to fetch the result until someone `handle` it
   */
  function eager():Future<T>;
}

private class NeverFuture<T> implements FutureObject<T> {
  public static var inst(default, null):NeverFuture<Dynamic> = new NeverFuture();
  function new() {}
  public function map<R>(f:T->R):Future<R> return cast inst;
  public function flatMap<R>(f:T->Future<R>):Future<R> return cast inst;
  public function handle(callback:Callback<T>):CallbackLink return null;
  public function gather():Future<T> return cast inst;
  public function eager():Future<T> return cast inst;
}

private class SyncFuture<T> implements FutureObject<T> {
  
  var value:Lazy<T>;

  public inline function new(value)
    this.value = value;

  public inline function map<R>(f:T->R):Future<R>
    return new SyncFuture(value.map(f));

  public inline function flatMap<R>(f:T->Future<R>):Future<R>
    return new SuspendableFuture(function (yield) return f(value.get()).handle(yield));

  public function handle(cb:Callback<T>):CallbackLink {
    cb.invoke(value);
    return null;
  }

  public function eager()
    return this;

  public function gather()
    return this;
}

class FutureTrigger<T> implements FutureObject<T> {
  var result:T;
  var list:CallbackList<T>;

  public function new() 
    this.list = new CallbackList();
  
  public function handle(callback:Callback<T>):CallbackLink
    return switch list {
      case null: 
        callback.invoke(result);
        null;
      case v:
        v.add(callback);
    }

  public function map<R>(f:T->R):Future<R>
    return switch list {
      case null: Future.sync(f(result));
      case v:
        var ret = new FutureTrigger();
        list.add(function (v) ret.trigger(f(v)));
        ret;
    }

  public function flatMap<R>(f:T->Future<R>):Future<R>
    return switch list {
      case null: f(result);
      case v:
        var ret = new FutureTrigger();
        list.add(function (v) f(v).handle(ret.trigger));
        ret;
    }

  public inline function gather()
    return this;

  public function eager()
    return this;

  public inline function asFuture():Future<T>
    return this;

  @:noUsing static public function gatherFuture<T>(f:Future<T>):Future<T> 
    return new SuspendableFuture(function (yield) return f.handle(yield));

  /**
   *  Triggers a value for this future
   */
  public function trigger(result:T):Bool
    return
      if (list == null) false;
      else {
        var list = this.list;
        this.list = null;
        this.result = result;
        list.invoke(result, true);
        true;
      }
}

typedef Surprise<D, F> = Future<Outcome<D, F>>;

#if js
class JsPromiseTools {
  static inline public function toSurprise<A>(promise:JsPromise<A>):Surprise<A, Error>
    return Future.ofJsPromise(promise);
  static inline public function toPromise<A>(promise:JsPromise<A>):Promise<A>
    return Future.ofJsPromise(promise);
}
#end

private class SuspendableFuture<T> implements FutureObject<T> {//TODO: this has quite a bit of duplication with FutureTrigger
  var callbacks:CallbackList<T>;
  var result:T;
  var suspended:Bool = true;
  var link:CallbackLink;
  var wakeup:(T->Void)->CallbackLink;

  public function new(wakeup) {
    this.wakeup = wakeup;
    this.callbacks = new CallbackList();

    callbacks.ondrain = function () if (callbacks != null) {
      suspended = true;
      link.cancel();
      link = null;
    }
  }

  function trigger(value:T) 
    switch callbacks {
      case null: 
      case list:
        callbacks = null;
        suspended = false;
        result = value;
        link = null;//consider disolving
        wakeup = null;
        list.invoke(value, true);
    }

  public function handle(callback:Callback<T>):CallbackLink 
    return 
      switch callbacks {
        case null: 
          callback.invoke(result);
          null;
        case v: 
          var ret = callbacks.add(callback);
          if (suspended) {
            suspended = false;
            link = wakeup(trigger);
          }
          ret;
      }
    

  public function map<R>(f:T->R):Future<R>
    return new SuspendableFuture(function (yield) {
      return this.handle(function (res) yield(f(res)));
    });

  public function flatMap<R>(f:T->Future<R>):Future<R>
    return Future.flatten(map(f));

  public inline function gather():Future<T> 
    return this;

  public inline function eager():Future<T> {
    handle(function () {});//TODO: very naive implementeation
    return this;
  }  

}