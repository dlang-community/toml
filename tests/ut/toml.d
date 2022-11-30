module ut.toml;

import std.experimental.logger;
import unit_threaded;
import toml;
import std.ascii : newline;
import std.exception : enforce, assertThrown;
import std.math : isNaN, isFinite;
import std.conv : to;

@("complete")
@safe
unittest {
   TOMLDocument doc;

   // tests from the official documentation
   // https://github.com/toml-lang/toml/blob/master/README.md

   doc = parseTOML(`
      # This is a TOML document.

      title = "TOML Example"

      [owner]
      name = "Tom Preston-Werner"
      dob = 1979-05-27T07:32:00-08:00 # First class dates

      [database]
      server = "192.168.1.1"
      ports = [ 8001, 8001, 8002 ]
      connection_max = 5000
      enabled = true

      [servers]

        # Indentation (tabs and/or spaces) is allowed but not required
        [servers.alpha]
        ip = "10.0.0.1"
        dc = "eqdc10"

        [servers.beta]
        ip = "10.0.0.2"
        dc = "eqdc10"

      [clients]
      data = [ ["gamma", "delta"], [1, 2] ]

      # Line breaks are OK when inside arrays
      hosts = [
        "alpha",
        "omega"
      ]
   `);
   doc["title"].should == "TOML Example";
   doc["owner"]["name"].should == "Tom Preston-Werner";
   doc["owner"]["dob"].should == SysTime.fromISOExtString("1979-05-27T07:32:00-08:00");
   doc["database"]["server"].should == "192.168.1.1";
   doc["database"]["ports"].should == [8001, 8001, 8002];
   doc["database"]["connection_max"].should == 5000;
   doc["database"]["enabled"].boolean.shouldBeTrue;
   doc["servers"]["alpha"]["ip"].should == "10.0.0.1";
   doc["servers"]["alpha"]["dc"].should == "eqdc10";
   doc["clients"]["data"][0].should == ["gamma", "delta"];
   doc["clients"]["data"][1].should == [1, 2];
   doc["clients"]["hosts"].should == ["alpha", "omega"];
}

@("comment")
@safe
unittest {
   TOMLDocument doc;

   doc = parseTOML(`
      # This is a full-line comment
      key = "value"
   `);
   ("key" in doc).shouldBeTrue;
   doc["key"].type.should == TOML_TYPE.STRING;
   doc["key"].str.should == "value";

   foreach (k, v; doc) {
      k.should == "key";
      v.type.should == TOML_TYPE.STRING;
      v.str.should == "value";
   }
   parseTOML(`key = # INVALID`).shouldThrow!TOMLException;
   parseTOML("key =\nkey2 = 'test'").shouldThrow!TOMLException;
}

@("bare keys")
@safe
unittest {
   TOMLDocument doc;
   // bare keys
   doc = parseTOML(`
      key = "value"
      bare_key = "value"
      bare-key = "value"
      1234 = "value"
   `);
   doc["key"].should == "value";
   doc["bare_key"].should == "value";
   doc["bare-key"].should == "value";
   doc["1234"].should == "value";
}
@("quoted keys")
@safe
unittest {
   TOMLDocument doc;

   doc = parseTOML(`
      "127.0.0.1" = "value"
      "character encoding" = "value"
      "ʎǝʞ" = "value"
      'key2' = "value"
      'quoted "value"' = "value"
   `);
   doc["127.0.0.1"].should == "value";
   doc["character encoding"].should == "value";
   doc["ʎǝʞ"].should == "value";
   doc["key2"].should == "value";
   doc["quoted \"value\""].should == "value";

   // no key name
   parseTOML(`= "no key name" # INVALID`).shouldThrow!TOMLException;

   // empty key
   parseTOML(`"" = "blank"`)[""].should == "blank";
   parseTOML(`'' = 'blank'`)[""].should == "blank";

   // dotted keys
   doc = parseTOML(`
      name = "Orange"
      physical.color = "orange"
      physical.shape = "round"
      site."google.com" = true
   `);
   assert(doc["name"] == "Orange");
   assert(doc["physical"] == ["color": "orange", "shape": "round"]);
   assert(doc["site"]["google.com"] == true);
}
@("string")
@safe
unittest {
   TOMLDocument doc;
   // basic strings
   doc = parseTOML(`str = "I'm a string. \"You can quote me\". Name\tJos\u00E9\nLocation\tSF."`);
   doc["str"].should == "I'm a string. \"You can quote me\". Name\tJosé\nLocation\tSF.";

   // multi-line basic strings
   doc = parseTOML(`str1 = """
Roses are red
Violets are blue"""`);
   version (Posix) {
      doc["str1"].should == "Roses are red\nViolets are blue";
   } else {
      doc["str1"].should == "Roses are red\r\nViolets are blue";
   }

   doc = parseTOML(`
      # The following strings are byte-for-byte equivalent:
      str1 = "The quick brown fox jumps over the lazy dog."

      str2 = """
The quick brown \


        fox jumps over \
          the lazy dog."""

      str3 = """\
         The quick brown \
         fox jumps over \
         the lazy dog.\
       """`);
   doc["str1"].should == "The quick brown fox jumps over the lazy dog.";
   doc["str1"].should == doc["str2"];
   doc["str1"].should == doc["str3"];

   // literal strings
   doc = parseTOML(`
      # What you see is what you get.
      winpath  = 'C:\Users\nodejs\templates'
      winpath2 = '\\ServerX\admin$\system32\'
      quoted   = 'Tom "Dubs" Preston-Werner'
      regex    = '<\i\c*\s*>'
   `);
   doc["winpath"].should == `C:\Users\nodejs\templates`;
   doc["winpath2"].should == `\\ServerX\admin$\system32\`;
   doc["quoted"].should == `Tom "Dubs" Preston-Werner`;
   doc["regex"].should == `<\i\c*\s*>`;
}

@("multi-line")
@safe
unittest {
   TOMLDocument doc;
   // dfmt off
   doc = parseTOML(`
      regex2 = '''I [dw]on't need \d{2} apples'''
      lines  = '''
The first newline is
trimmed in raw strings.
   All other whitespace
   is preserved.
'''`);
   doc["regex2"].should == `I [dw]on't need \d{2} apples`;
   doc["lines"].should == "The first newline is" ~ newline
      ~ "trimmed in raw strings." ~ newline
      ~ "   All other whitespace" ~ newline
      ~ "   is preserved." ~ newline;
   // dfmt on
}

@("integer")
@safe
unittest {
   TOMLDocument doc;
   doc = parseTOML(`
      int1 = +99
      int2 = 42
      int3 = 0
      int4 = -17
   `);
   doc["int1"].type.should == TOMLType.INTEGER;
   doc["int1"].integer.should == 99;
   doc["int2"].should == 42;
   doc["int3"].should == 0;
   doc["int4"].should == -17;

   doc = parseTOML(`
      int5 = 1_000
      int6 = 5_349_221
      int7 = 1_2_3_4_5     # VALID but discouraged
   `);
   assert(doc["int5"] == 1_000);
   assert(doc["int6"] == 5_349_221);
   assert(doc["int7"] == 1_2_3_4_5);

   // leading 0s not allowed
   parseTOML(`invalid = 01`).shouldThrow!TOMLException;

   // underscores must be enclosed in numbers
   parseTOML(`invalid = _123`).shouldThrow!TOMLException;
   parseTOML(`invalid = 123_`).shouldThrow!TOMLException;
   parseTOML(`invalid = 123__123`).shouldThrow!TOMLException;
   parseTOML(`invalid = 0b01_21`).shouldThrow!TOMLException;
   parseTOML(`invalid = 0x_deadbeef`).shouldThrow!TOMLException;
   parseTOML(`invalid = 0b0101__00`).shouldThrow!TOMLException;

   doc = parseTOML(`
      # hexadecimal with prefix 0x
      hex1 = 0xDEADBEEF
      hex2 = 0xdeadbeef
      hex3 = 0xdead_beef

      # octal with prefix 0o
      oct1 = 0o01234567
      oct2 = 0o755 # useful for Unix file permissions

      # binary with prefix 0b
      bin1 = 0b11010110
   `);
   assert(doc["hex1"] == 0xDEADBEEF);
   assert(doc["hex2"] == 0xdeadbeef);
   assert(doc["hex3"] == 0xdead_beef);
   assert(doc["oct1"] == 342391);
   assert(doc["oct2"] == 493);
   assert(doc["bin1"] == 0b11010110);

   assertThrown!TOMLException({ parseTOML(`invalid = 0h111`); }());

   // -----
   // Float
   // -----

   doc = parseTOML(`
      # fractional
      flt1 = +1.0
      flt2 = 3.1415
      flt3 = -0.01

      # exponent
      flt4 = 5e+22
      flt5 = 1e6
      flt6 = -2E-2

      # both
      flt7 = 6.626e-34
   `);
   assert(doc["flt1"].type == TOML_TYPE.FLOAT);
   assert(doc["flt1"].floating == 1);
   assert(doc["flt2"] == 3.1415);
   assert(doc["flt3"] == -.01);
   assert(doc["flt4"] == 5e+22);
   assert(doc["flt5"] == 1e6);
   assert(doc["flt6"] == -2E-2);
   assert(doc["flt7"] == 6.626e-34);

   doc = parseTOML(`flt8 = 9_224_617.445_991_228_313`);
   assert(doc["flt8"] == 9_224_617.445_991_228_313);

   doc = parseTOML(`
      # infinity
      sf1 = inf  # positive infinity
      sf2 = +inf # positive infinity
      sf3 = -inf # negative infinity

      # not a number
      sf4 = nan  # actual sNaN/qNaN encoding is implementation specific
      sf5 = +nan # same as nan
      sf6 = -nan # valid, actual encoding is implementation specific
   `);
   assert(doc["sf1"] == double.infinity);
   assert(doc["sf2"] == double.infinity);
   assert(doc["sf3"] == -double.infinity);
   assert(doc["sf4"].floating.isNaN());
   assert(doc["sf5"].floating.isNaN());
   assert(doc["sf6"].floating.isNaN());

   // -------
   // Boolean
   // -------

   doc = parseTOML(`
      bool1 = true
      bool2 = false
   `);
   assert(doc["bool1"].type == TOML_TYPE.TRUE);
   assert(doc["bool2"].type == TOML_TYPE.FALSE);
   assert(doc["bool1"] == true);
   assert(doc["bool2"] == false);

   // ----------------
   // Offset Date-Time
   // ----------------

   doc = parseTOML(`
      odt1 = 1979-05-27T07:32:00Z
      odt2 = 1979-05-27T00:32:00-07:00
      odt3 = 1979-05-27T00:32:00.999999-07:00
   `);
   assert(doc["odt1"].type == TOML_TYPE.OFFSET_DATETIME);
   assert(doc["odt1"].offsetDatetime == SysTime.fromISOExtString("1979-05-27T07:32:00Z"));
   assert(doc["odt2"] == SysTime.fromISOExtString("1979-05-27T00:32:00-07:00"));
   assert(doc["odt3"] == SysTime.fromISOExtString("1979-05-27T00:32:00.999999-07:00"));

   doc = parseTOML(`odt4 = 1979-05-27 07:32:00Z`);
   assert(doc["odt4"] == SysTime.fromISOExtString("1979-05-27T07:32:00Z"));

   // ---------------
   // Local Date-Time
   // ---------------

   doc = parseTOML(`
      ldt1 = 1979-05-27T07:32:00
      ldt2 = 1979-05-27T00:32:00.999999
   `);
   assert(doc["ldt1"].type == TOML_TYPE.LOCAL_DATETIME);
   assert(doc["ldt1"].localDatetime == DateTime.fromISOExtString("1979-05-27T07:32:00"));
   assert(doc["ldt2"] == DateTime.fromISOExtString("1979-05-27T00:32:00.999999"));

   // ----------
   // Local Date
   // ----------

   doc = parseTOML(`
      ld1 = 1979-05-27
   `);
   assert(doc["ld1"].type == TOML_TYPE.LOCAL_DATE);
   assert(doc["ld1"].localDate == Date.fromISOExtString("1979-05-27"));

   // ----------
   // Local Time
   // ----------

   doc = parseTOML(`
      lt1 = 07:32:00
      lt2 = 00:32:00.999999
   `);
   assert(doc["lt1"].type == TOML_TYPE.LOCAL_TIME);
   assert(doc["lt1"].localTime == TimeOfDay.fromISOExtString("07:32:00"));
   assert(doc["lt2"] == TimeOfDay.fromISOExtString("00:32:00.999999"));
   assert(doc["lt2"].localTime.fracSecs.total!"msecs" == 999999);

   // -----
   // Array
   // -----

   doc = parseTOML(`
      arr1 = [ 1, 2, 3 ]
      arr2 = [ "red", "yellow", "green" ]
      arr3 = [ [ 1, 2 ], [3, 4, 5] ]
      arr4 = [ "all", 'strings', """are the same""", '''type''']
      arr5 = [ [ 1, 2 ], ["a", "b", "c"] ]
   `);
   assert(doc["arr1"].type == TOML_TYPE.ARRAY);
   assert(doc["arr1"].array == [TOMLValue(1), TOMLValue(2), TOMLValue(3)]);
   assert(doc["arr2"] == ["red", "yellow", "green"]);
   assert(doc["arr3"] == [[1, 2], [3, 4, 5]]);
   assert(doc["arr4"] == ["all", "strings", "are the same", "type"]);
   assert(doc["arr5"] == [TOMLValue([1, 2]), TOMLValue(["a", "b", "c"])]);

   assertThrown!TOMLException({ parseTOML(`arr6 = [ 1, 2.0 ]`); }());

   doc = parseTOML(`
      arr7 = [
        1, 2, 3
      ]

      arr8 = [
        1,
        2, # this is ok
      ]
   `);
   assert(doc["arr7"] == [1, 2, 3]);
   assert(doc["arr8"] == [1, 2]);

   // -----
   // Table
   // -----

   doc = parseTOML(`
      [table-1]
      key1 = "some string"
      key2 = 123

      [table-2]
      key1 = "another string"
      key2 = 456
   `);
   assert(doc["table-1"].type == TOML_TYPE.TABLE);
   assert(doc["table-1"] == ["key1": TOMLValue("some string"), "key2": TOMLValue(123)]);
   assert(doc["table-2"] == ["key1": TOMLValue("another string"), "key2": TOMLValue(456)]);

   doc = parseTOML(`
      [dog."tater.man"]
      type.name = "pug"
   `);
   assert(doc["dog"]["tater.man"]["type"]["name"] == "pug");

   doc = parseTOML(`
      [a.b.c]            # this is best practice
      [ d.e.f ]          # same as [d.e.f]
      [ g .  h  . i ]    # same as [g.h.i]
      [ j . "ʞ" . 'l' ]  # same as [j."ʞ".'l']
   `);
   assert(doc["a"]["b"]["c"].type == TOML_TYPE.TABLE);
   assert(doc["d"]["e"]["f"].type == TOML_TYPE.TABLE);
   assert(doc["g"]["h"]["i"].type == TOML_TYPE.TABLE);
   assert(doc["j"]["ʞ"]["l"].type == TOML_TYPE.TABLE);

   doc = parseTOML(`
      # [x] you
      # [x.y] don't
      # [x.y.z] need these
      [x.y.z.w] # for this to work
   `);
   assert(doc["x"]["y"]["z"]["w"].type == TOML_TYPE.TABLE);

   doc = parseTOML(`
      [a.b]
      c = 1

      [a]
      d = 2
   `);
   assert(doc["a"]["b"]["c"] == 1);
   assert(doc["a"]["d"] == 2);

   assertThrown!TOMLException({ parseTOML(`
         # DO NOT DO THIS

         [a]
         b = 1

         [a]
         c = 2
      `); }());

   assertThrown!TOMLException({ parseTOML(`
         # DO NOT DO THIS EITHER

         [a]
         b = 1

         [a.b]
         c = 2
      `); }());

   assertThrown!TOMLException({ parseTOML(`[]`); }());
   assertThrown!TOMLException({ parseTOML(`[a.]`); }());
   assertThrown!TOMLException({ parseTOML(`[a..b]`); }());
   assertThrown!TOMLException({ parseTOML(`[.b]`); }());
   assertThrown!TOMLException({ parseTOML(`[.]`); }());

   // ------------
   // Inline Table
   // ------------

   doc = parseTOML(`
      name = { first = "Tom", last = "Preston-Werner" }
      point = { x = 1, y = 2 }
      animal = { type.name = "pug" }
   `);
   assert(doc["name"]["first"] == "Tom");
   assert(doc["name"]["last"] == "Preston-Werner");
   assert(doc["point"] == ["x": 1, "y": 2]);
   assert(doc["animal"]["type"]["name"] == "pug");

   // ---------------
   // Array of Tables
   // ---------------

   doc = parseTOML(`
      [[products]]
      name = "Hammer"
      sku = 738594937

      [[products]]

      [[products]]
      name = "Nail"
      sku = 284758393
      color = "gray"
   `);
   assert(doc["products"].type == TOML_TYPE.ARRAY);
   assert(doc["products"].array.length == 3);
   assert(doc["products"][0] == ["name": TOMLValue("Hammer"), "sku": TOMLValue(738594937)]);
   assert(doc["products"][1] == (TOMLValue[string]).init);
   assert(doc["products"][2] == ["name": TOMLValue("Nail"), "sku": TOMLValue(284758393), "color": TOMLValue("gray")]);

   // nested
   doc = parseTOML(`
      [[fruit]]
        name = "apple"

        [fruit.physical]
          color = "red"
          shape = "round"

        [[fruit.variety]]
          name = "red delicious"

        [[fruit.variety]]
          name = "granny smith"

      [[fruit]]
        name = "banana"

        [[fruit.variety]]
          name = "plantain"
   `);
   assert(doc["fruit"].type == TOML_TYPE.ARRAY);
   assert(doc["fruit"].array.length == 2);
   assert(doc["fruit"][0]["name"] == "apple");
   assert(doc["fruit"][0]["physical"] == ["color": "red", "shape": "round"]);
   assert(doc["fruit"][0]["variety"][0] == ["name": "red delicious"]);
   assert(doc["fruit"][0]["variety"][1]["name"] == "granny smith");
   assert(doc["fruit"][1] == ["name": TOMLValue("banana"), "variety": TOMLValue([["name": "plantain"]])]);

   assertThrown!TOMLException({ parseTOML(`
         # INVALID TOML DOC
         [[fruit]]
           name = "apple"

           [[fruit.variety]]
             name = "red delicious"

           # This table conflicts with the previous table
           [fruit.variety]
             name = "granny smith"
      `); }());

   doc = parseTOML(`
      points = [ { x = 1, y = 2, z = 3 },
         { x = 7, y = 8, z = 9 },
         { x = 2, y = 4, z = 8 } ]
   `);
   assert(doc["points"].array.length == 3);
   assert(doc["points"][0] == ["x": 1, "y": 2, "z": 3]);
   assert(doc["points"][1] == ["x": 7, "y": 8, "z": 9]);
   assert(doc["points"][2] == ["x": 2, "y": 4, "z": 8]);

   // additional tests for code coverage

   assert(TOMLValue(42) == 42.0);
   assert(TOMLValue(42) != "42");
   assert(TOMLValue("42") != 42);

   try {
      // dfmt off
      parseTOML(`

         error = @
      `);
      // dfmt on
   } catch (TOMLParserException e) {
      assert(e.position.line == 3); // start from line 1
      assert(e.position.column == 18);
   }

   assertThrown!TOMLException({ parseTOML(`error = "unterminated`); }());
   assertThrown!TOMLException({ parseTOML(`error = 'unterminated`); }());
   assertThrown!TOMLException({ parseTOML(`error = "\ "`); }());

   assertThrown!TOMLException({ parseTOML(`error = truè`); }());
   assertThrown!TOMLException({ parseTOML(`error = falsè`); }());

   assertThrown!TOMLException({ parseTOML(`[error`); }());

   doc = parseTOML(`test = "\\\"\b\t\n\f\r\u0040\U00000040"`);
   assert(doc["test"] == "\\\"\b\t\n\f\r@@");

   doc = parseTOML(`test = """quoted "string"!"""`);
   assert(doc["test"] == "quoted \"string\"!");

   // options

   assert(parseTOML(`raw = this is unquoted`, TOMLOptions.unquotedStrings)["raw"] == "this is unquoted");

   // document

   TOMLValue value = TOMLValue(["test": 44]);
   doc = TOMLDocument(value);

   // opEquals

   assert(const TOMLValue(true) == TOMLValue(true));
   assert(const TOMLValue("string") == TOMLValue("string"));
   assert(const TOMLValue(0) == TOMLValue(0));
   assert(const TOMLValue(.0) == TOMLValue(.0));
   assert(const TOMLValue(SysTime.fromISOExtString("1979-05-27T00:32:00-07:00")) == TOMLValue(
         SysTime.fromISOExtString("1979-05-27T00:32:00-07:00")));
   assert(const TOMLValue(DateTime.fromISOExtString("1979-05-27T07:32:00")) == TOMLValue(DateTime.fromISOExtString("1979-05-27T07:32:00")));
   assert(const TOMLValue(Date.fromISOExtString("1979-05-27")) == TOMLValue(Date.fromISOExtString("1979-05-27")));
   assert(const TOMLValue(TimeOfDay.fromISOExtString("07:32:00")) == TOMLValue(TimeOfDay.fromISOExtString("07:32:00")));
   assert(const TOMLValue([1, 2, 3]) == TOMLValue([1, 2, 3]));
   assert(const TOMLValue(["a": 0, "b": 1]) == TOMLValue(["a": 0, "b": 1]));

   // toString()

   assert(TOMLDocument(["test": TOMLValue(0)]).toString() == "test = 0" ~ newline);

   assert((const TOMLValue(true)).toString() == "true");
   assert((const TOMLValue("string")).toString() == "\"string\"");
   assert((const TOMLValue("\"quoted \\ \b \f \r\n \t string\"")).toString() == "\"\\\"quoted \\\\ \\b \\f \\r\\n \\t string\\\"\"");
   assert((const TOMLValue(42)).toString() == "42");
   assert((const TOMLValue(99.44)).toString() == "99.44");
   assert((const TOMLValue(.0)).toString() == "0.0");
   assert((const TOMLValue(1e100)).toString() == "1e+100");
   assert((const TOMLValue(SysTime.fromISOExtString("1979-05-27T00:32:00-07:00"))).toString() == "1979-05-27T00:32:00-07:00");
   assert((const TOMLValue(DateTime.fromISOExtString("1979-05-27T07:32:00"))).toString() == "1979-05-27T07:32:00");
   assert((const TOMLValue(Date.fromISOExtString("1979-05-27"))).toString() == "1979-05-27");
   assert((const TOMLValue(TimeOfDay.fromISOExtString("07:32:00.999999"))).toString() == "07:32:00.999999");
   assert((const TOMLValue([1, 2, 3])).toString() == "[1, 2, 3]");
   immutable table = TOMLValue(["a": 0, "b": 1]).toString();
   assert(table == "{ a = 0, b = 1 }" || table == "{ b = 1, a = 0 }");

   foreach (k, v; TOMLValue(["0": 0, "1": 1])) {
      assert(v == k.to!int);
   }

   foreach (k, const v; const(TOMLValue)(["0": 0, "1": 1])) {
      assert(v == k.to!int);
   }

   foreach (k, ref const v; const(TOMLValue)(["0": 0, "1": 1])) {
      assert(v == k.to!int);
   }

   static if (__VERSION__ >= 2098) {
      mixin(q{
         foreach (k, scope v; TOMLValue(["0": 0, "1": 1])) {
            assert(v == k.to!int);
         }

         foreach (k, scope const v; TOMLValue(["0": 0, "1": 1])) {
            assert(v == k.to!int);
         }

         foreach (k, scope ref v; TOMLValue(["0": 0, "1": 1])) {
            assert(v == k.to!int);
         }

         foreach (k, scope ref const v; const(TOMLValue)(["0": 0, "1": 1])) {
            assert(v == k.to!int);
         }
      });
   }

   value = 42;
   assert(value.type == TOML_TYPE.INTEGER);
   assert(value == 42);
   value = TOMLValue("42");
   assert(value.type == TOML_TYPE.STRING);
   assert(value == "42");
}
