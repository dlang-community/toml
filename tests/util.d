module util;

import std.typecons : Flag;

T generate(T, Flag!"randomValue" randomValue = true)() {
   import std.traits : hasMember;
   import std.random : Random, uniform, unpredictableSeed;
   import std.conv : to;
   import std.datetime : SysTime;

   Random rnd = Random(unpredictableSeed);

   T target;
   foreach (member; __traits(allMembers, T)) {
      static if (member != "opAssign") {
      auto m = __traits(getMember, target, member);

      static if (is(typeof(m) == int)) {
         __traits(getMember, target, member) = randomValue ? uniform(-1024, 1024, rnd) : 42;
      } else static if (is(typeof(m) == long)) {
         __traits(getMember, target, member) = randomValue ? uniform(-1024, 1024, rnd) : 42;
      } else static if (is(typeof(m) == float)) {
         __traits(getMember, target, member) = randomValue ? uniform(-1971., 1971., rnd) : 19.71;
      } else static if (is(typeof(m) == double)) {
         __traits(getMember, target, member) = randomValue ? uniform(-1964., 1964., rnd) : 19.64;
      } else static if (is(typeof(m) == bool)) {
         __traits(getMember, target, member) = randomValue ? uniform(-1024, 1024, rnd) > 0 : true;
      } else static if (is(typeof(m) == string)) {
         __traits(getMember, target, member) = randomValue ? "s" ~ uniform(0, 100, rnd).to!string() : "cul";
         } else static if (is(typeof(m) == SysTime)) {
            __traits(getMember, target, member) = SysTime.fromISOExtString("2004-08-29T10:30:01Z");
         }
      }
   }
   return target;
}
