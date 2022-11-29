// Written in the D programming language.

/**
 *
 * Tom's Obvious, Minimal Language (v1.0.0).
 *
 * License: $(HTTP https://github.com/Kripth/toml/blob/master/LICENSE, MIT)
 * Authors: Kripth
 * References: $(LINK https://github.com/toml-lang/toml/blob/master/README.md)
 * Source: $(HTTP https://github.com/Kripth/toml/blob/master/src/toml/toml.d, toml/_toml.d)
 *
 */
module toml.toml;

import std.algorithm : canFind, min, stripRight;
import std.array : Appender;
import std.ascii : newline;
import std.conv : text, to;
import std.datetime : Date, DateTimeD = DateTime, SysTime, TimeOfDayD = TimeOfDay;
import std.exception : assertThrown, enforce;
import std.string : indexOf, join, replace, strip;
import std.traits : isArray, isAssociativeArray, isFloatingPoint, isIntegral, isNumeric, KeyType;
import std.typecons : Tuple;
import std.utf : encode, UseReplacementDchar;

import toml.datetime : DateTime, TimeOfDay;

/**
 * Flags that control how a TOML document is parsed and encoded.
 */
enum TOMLOptions {
   none = 0x00,
   unquotedStrings = 0x01, /// allow unquoted strings as values when parsing
}

/**
 * TOML type enumeration.
 */
enum TOML_TYPE : byte {
   STRING, /// Indicates the type of a TOMLValue.
   INTEGER, /// ditto
   FLOAT, /// ditto
   OFFSET_DATETIME, /// ditto
   LOCAL_DATETIME, /// ditto
   LOCAL_DATE, /// ditto
   LOCAL_TIME, /// ditto
   ARRAY, /// ditto
   TABLE, /// ditto
   TRUE, /// ditto
   FALSE /// ditto
}

alias TOMLType = TOML_TYPE;
alias TOMLfloat = TOML_TYPE.FLOAT;

/**
 * Main table of a TOML document.
 * It works as a TOMLValue with the TOML_TYPE.TABLE type.
 */
struct TOMLDocument {

   public TOMLValue[string] table;

@safe scope:

   public this(TOMLValue[string] table) pure {
      this.table = table;
   }

   public this(TOMLValue value) pure {
      this(value.table);
   }

   public string toString() const {
      Appender!string appender;
      foreach (key, value; this.table) {
         appender.put(formatKey(key));
         appender.put(" = ");
         value.append(appender);
         appender.put(newline);
      }
      return appender.data;
   }

   alias table this;

}

/**
 * Value of a TOML value.
 */
struct TOMLValue {

   private union Store {
      string str;
      long integer;
      double floating;
      SysTime offsetDatetime;
      DateTime localDatetime;
      Date localDate;
      TimeOfDay localTime;
      TOMLValue[] array;
      TOMLValue[string] table;
   }

   private Store store;
   private TOML_TYPE _type;

   public int opApply(scope int delegate(string, ref TOMLValue) @safe dg) @trusted {
      return opApplyImpl(cast(OpApplyTableT) dg);
   }

   public int opApply(scope int delegate(string, ref TOMLValue) @safe pure dg) @trusted pure {
      return opApplyImpl(cast(OpApplyTableT) dg);
   }

   public int opApply(scope int delegate(string, ref TOMLValue) @system dg) @system {
      return opApplyImpl(cast(OpApplyTableT) dg);
   }

   public int opApply(scope int delegate(string, ref TOMLValue) @system pure dg) @system pure {
      return opApplyImpl(cast(OpApplyTableT) dg);
   }

@safe scope:

   public this(T)(T value) {
      static if (is(T == TOML_TYPE)) {
         this._type = value;
      } else {
         this.assign(value);
      }
   }

   public pure nothrow @property @safe @nogc TOML_TYPE type() return const {
      return this._type;
   }

   /**
    * Throws: TOMLException if type is not TOML_TYPE.STRING
    */
   public @property @trusted string str() return const pure {
      enforce!TOMLException(this._type == TOML_TYPE.STRING, "TOMLValue is not a string");
      return this.store.str;
   }

   /**
    * Throws: TOMLException if type is not TOML_TYPE.INTEGER
    */
   public @property @trusted long integer() return const pure {
      enforce!TOMLException(this._type == TOML_TYPE.INTEGER, "TOMLValue is not an integer");
      return this.store.integer;
   }

   /**
    * Throws: TOMLException if type is not TOML_TYPE.FLOAT
    */
   public @property @trusted double floating() return const pure {
      enforce!TOMLException(this._type == TOML_TYPE.FLOAT, "TOMLValue is not a float");
      return this.store.floating;
   }

   /**
    * Throws: TOMLException if type is not TOML_TYPE.TRUE or TOML_TYPE.FALSE
    */
   public @property @trusted bool boolean() return const pure {
      switch (this._type) {
         case TOML_TYPE.TRUE:
            return true;
         case TOML_TYPE.FALSE:
            return false;
         default:
            throw new TOMLException("TOMLValue is not a boolean");
      }
   }

   /**
    * Throws: TOMLException if type is not TOML_TYPE.OFFSET_DATETIME
    */
   public @property @trusted ref inout(SysTime) offsetDatetime() return inout pure {
      enforce!TOMLException(this.type == TOML_TYPE.OFFSET_DATETIME, "TOMLValue is not an offset datetime");
      return this.store.offsetDatetime;
   }

   /**
    * Throws: TOMLException if type is not TOML_TYPE.LOCAL_DATETIME
    */
   public @property @trusted ref inout(DateTime) localDatetime() return inout pure {
      enforce!TOMLException(this._type == TOML_TYPE.LOCAL_DATETIME, "TOMLValue is not a local datetime");
      return this.store.localDatetime;
   }

   /**
    * Throws: TOMLException if type is not TOML_TYPE.LOCAL_DATE
    */
   public @property @trusted ref inout(Date) localDate() return inout pure {
      enforce!TOMLException(this._type == TOML_TYPE.LOCAL_DATE, "TOMLValue is not a local date");
      return this.store.localDate;
   }

   /**
    * Throws: TOMLException if type is not TOML_TYPE.LOCAL_TIME
    */
   public @property @trusted ref inout(TimeOfDay) localTime() return inout pure {
      enforce!TOMLException(this._type == TOML_TYPE.LOCAL_TIME, "TOMLValue is not a local time");
      return this.store.localTime;
   }

   /**
    * Throws: TOMLException if type is not TOML_TYPE.ARRAY
    */
   public @property @trusted ref inout(TOMLValue[]) array() return inout pure {
      enforce!TOMLException(this._type == TOML_TYPE.ARRAY, "TOMLValue is not an array");
      return this.store.array;
   }

   /**
    * Throws: TOMLException if type is not TOML_TYPE.TABLE
    */
   public @property @trusted ref inout(TOMLValue[string]) table() return inout pure {
      enforce!TOMLException(this._type == TOML_TYPE.TABLE, "TOMLValue is not a table");
      return this.store.table;
   }

   public inout(TOMLValue) opIndex(size_t index) return inout pure {
      return this.array[index];
   }

   public inout(TOMLValue)* opBinaryRight(string op : "in")(string key) return inout pure {
      return key in this.table;
   }

   public inout(TOMLValue) opIndex(string key) return inout pure {
      return this.table[key];
   }

   public int opApply(scope int delegate(string, scope ref TOMLValue) @safe dg) @trusted {
      return opApplyImpl(cast(OpApplyTableT) dg);
   }

   public int opApply(scope int delegate(string, scope ref TOMLValue) @safe pure dg) @trusted pure {
      return opApplyImpl(cast(OpApplyTableT) dg);
   }

   public int opApply(scope int delegate(string, scope ref TOMLValue) @system dg) @system {
      return opApplyImpl(cast(OpApplyTableT) dg);
   }

   public int opApply(scope int delegate(string, scope ref TOMLValue) @system pure dg) @system pure {
      return opApplyImpl(cast(OpApplyTableT) dg);
   }

   private alias OpApplyTableT = int delegate(string, scope ref TOMLValue) @safe pure;
   private int opApplyImpl(scope OpApplyTableT dg) @safe pure {
      int result;
      foreach (string key, ref value; this.table) {
         result = dg(key, value);
         if (result) {
            break;
         }
      }
      return result;
   }

   public void opAssign(T)(T value) pure {
      this.assign(value);
   }

   private void assign(T)(T value) @trusted pure {
      static if (is(T == TOMLValue)) {
         this.store = value.store;
         this._type = value._type;
      } else static if (is(T : string)) {
         this.store.str = value;
         this._type = TOML_TYPE.STRING;
      } else static if (isIntegral!T) {
         this.store.integer = value;
         this._type = TOML_TYPE.INTEGER;
      } else static if (isFloatingPoint!T) {
         this.store.floating = value.to!double;
         this._type = TOML_TYPE.FLOAT;
      } else static if (is(T == SysTime)) {
         this.store.offsetDatetime = value;
         this._type = TOML_TYPE.OFFSET_DATETIME;
      } else static if (is(T == DateTime)) {
         this.store.localDatetime = value;
         this._type = TOML_TYPE.LOCAL_DATETIME;
      } else static if (is(T == DateTimeD)) {
         this.store.localDatetime = DateTime(value.date, TimeOfDay(value.timeOfDay));
         this._type = TOML_TYPE.LOCAL_DATETIME;
      } else static if (is(T == Date)) {
         this.store.localDate = value;
         this._type = TOML_TYPE.LOCAL_DATE;
      } else static if (is(T == TimeOfDay)) {
         this.store.localTime = value;
         this._type = TOML_TYPE.LOCAL_TIME;
      } else static if (is(T == TimeOfDayD)) {
         this.store.localTime = TimeOfDay(value);
         this._type = TOML_TYPE.LOCAL_TIME;
      } else static if (isArray!T) {
         static if (is(T == TOMLValue[])) {
            if (value.length) {
               // verify that every element has the same type
               TOML_TYPE cmp = value[0].type;
               foreach (element; value[1 .. $]) {
                  enforce!TOMLException(element.type == cmp, "Array's values must be of the same type");
               }
            }
            alias data = value;
         } else {
            TOMLValue[] data;
            foreach (element; value) {
               data ~= TOMLValue(element);
            }
         }
         this.store.array = data;
         this._type = TOML_TYPE.ARRAY;
      } else static if (isAssociativeArray!T && is(KeyType!T : string)) {
         static if (is(T == TOMLValue[string])) {
            alias data = value;
         } else {
            TOMLValue[string] data;
            foreach (key, v; value) {
               data[key] = v;
            }
         }
         this.store.table = data;
         this._type = TOML_TYPE.TABLE;
      } else static if (is(T == bool)) {
         _type = value ? TOML_TYPE.TRUE : TOML_TYPE.FALSE;
      } else {
         static assert(0);
      }
   }

   public bool opEquals(T)(scope T value) const @trusted pure {
      static if (is(T == TOMLValue)) {
         if (this._type != value._type) {
            return false;
         }
         final switch (this.type) with (TOML_TYPE) {
            case STRING:
               return this.store.str == value.store.str;
            case INTEGER:
               return this.store.integer == value.store.integer;
            case FLOAT:
               return this.store.floating == value.store.floating;
            case OFFSET_DATETIME:
               return this.store.offsetDatetime == value.store.offsetDatetime;
            case LOCAL_DATETIME:
               return this.store.localDatetime == value.store.localDatetime;
            case LOCAL_DATE:
               return this.store.localDate == value.store.localDate;
            case LOCAL_TIME:
               return this.store.localTime == value.store.localTime;
            case ARRAY:
               return this.store.array == value.store.array;
               //case TABLE: return this.store.table == value.store.table; // causes errors
            case TABLE:
               return this.opEquals(value.store.table);
            case TRUE:
            case FALSE:
               return true;
         }
      } else static if (is(T : string)) {
         return this._type == TOML_TYPE.STRING && this.store.str == value;
      } else static if (isNumeric!T) {
         if (this._type == TOML_TYPE.INTEGER) {
            return this.store.integer == value;
         } else if (this._type == TOML_TYPE.FLOAT) {
            return this.store.floating == value;
         } else {
            return false;
         }
      } else static if (is(T == SysTime)) {
         return this._type == TOML_TYPE.OFFSET_DATETIME && this.store.offsetDatetime == value;
      } else static if (is(T == DateTime)) {
         return this._type == TOML_TYPE.LOCAL_DATETIME && this.store.localDatetime.dateTime == value.dateTime
            && this.store.localDatetime.timeOfDay.fracSecs == value.timeOfDay.fracSecs;
      } else static if (is(T == DateTimeD)) {
         return this._type == TOML_TYPE.LOCAL_DATETIME && this.store.localDatetime.dateTime == value;
      } else static if (is(T == Date)) {
         return this._type == TOML_TYPE.LOCAL_DATE && this.store.localDate == value;
      } else static if (is(T == TimeOfDay)) {
         return this._type == TOML_TYPE.LOCAL_TIME && this.store.localTime.timeOfDay == value.timeOfDay
            && this.store.localTime.fracSecs == value.fracSecs;
      } else static if (is(T == TimeOfDayD)) {
         return this._type == TOML_TYPE.LOCAL_TIME && this.store.localTime == value;
      } else static if (isArray!T) {
         if (this._type != TOML_TYPE.ARRAY || this.store.array.length != value.length) {
            return false;
         }
         foreach (i, element; this.store.array) {
            if (element != value[i]) {
               return false;
            }
         }
         return true;
      } else static if (isAssociativeArray!T && is(KeyType!T : string)) {
         if (this._type != TOML_TYPE.TABLE || this.store.table.length != value.length) {
            return false;
         }
         foreach (key, v; this.store.table) {
            auto cmp = key in value;
            if (cmp is null || v != *cmp) {
               return false;
            }
         }
         return true;
      } else static if (is(T == bool)) {
         return value ? _type == TOML_TYPE.TRUE : _type == TOML_TYPE.FALSE;
      } else {
         return false;
      }
   }

   size_t toHash() const @trusted @nogc pure nothrow {
      final switch (_type) with (TOML_TYPE) {
         case STRING:
            return hashOf(store.str);
         case INTEGER:
            return hashOf(store.integer);
         case FLOAT:
            return hashOf(store.floating);
         case OFFSET_DATETIME:
            return hashOf(store.offsetDatetime);
         case LOCAL_DATETIME:
            return hashOf(store.localDatetime);
         case LOCAL_DATE:
            return hashOf(store.localDate);
         case LOCAL_TIME:
            return hashOf(store.localTime);
         case ARRAY:
            return hashOf(store.array);
         case TABLE:
            return hashOf(store.table);
         case TRUE:
            return hashOf(true);
         case FALSE:
            return hashOf(false);
      }
   }

   public void append(Output)(scope ref Output appender) const @trusted {
      final switch (this._type) with (TOML_TYPE) {
         case STRING:
            appender.put(formatString(this.store.str));
            break;
         case INTEGER:
            appender.put(this.store.integer.to!string);
            break;
         case FLOAT:
            immutable str = this.store.floating.to!string;
            appender.put(str);
            if (!str.canFind('.') && !str.canFind('e')) {
               appender.put(".0");
            }
            break;
         case OFFSET_DATETIME:
            appender.put(this.store.offsetDatetime.toISOExtString());
            break;
         case LOCAL_DATETIME:
            appender.put(this.store.localDatetime.toISOExtString());
            break;
         case LOCAL_DATE:
            appender.put(this.store.localDate.toISOExtString());
            break;
         case LOCAL_TIME:
            appender.put(this.store.localTime.toISOExtString());
            break;
         case ARRAY:
            appender.put("[");
            foreach (i, value; this.store.array) {
               value.append(appender);
               if (i + 1 < this.store.array.length) {
                  appender.put(", ");
               }
            }
            appender.put("]");
            break;
         case TABLE:
            // display as an inline table
            appender.put("{ ");
            size_t i = 0;
            foreach (key, value; this.store.table) {
               appender.put(formatKey(key));
               appender.put(" = ");
               value.append(appender);
               if (++i != this.store.table.length) {
                  appender.put(", ");
               }
            }
            appender.put(" }");
            break;
         case TRUE:
            appender.put("true");
            break;
         case FALSE:
            appender.put("false");
            break;
      }
   }

   public string toString() const {
      Appender!string appender;
      this.append(appender);
      return appender.data;
   }

}

private string formatKey(scope return string str) pure @safe {
   foreach (c; str) {
      if ((c < '0' || c > '9') && (c < 'A' || c > 'Z') && (c < 'a' || c > 'z') && c != '-' && c != '_') {
         return formatString(str);
      }
   }
   return str;
}

private string formatString(scope return inout(char)[] str) pure @safe {
   Appender!string appender;
   appender.put('"');
   foreach (c; str) {
      switch (c) {
         case '"':
            appender.put("\\\"");
            break;
         case '\\':
            appender.put("\\\\");
            break;
         case '\b':
            appender.put("\\b");
            break;
         case '\f':
            appender.put("\\f");
            break;
         case '\n':
            appender.put("\\n");
            break;
         case '\r':
            appender.put("\\r");
            break;
         case '\t':
            appender.put("\\t");
            break;
         default:
            appender.put(c);
      }
   }
   appender.put('"');
   return appender.data;
}

/**
 * Parses a TOML document.
 * Params:
 *  data = String in toml format to parse. Slices out of this will be returned
 *    _iff_ `unquotedStrings` is enabled in the options and a `string` is passed
 *    into this function.
 *  options = Parsing option
 *
 * Returns: a TOMLDocument with the parsed data
 * Throws:
 *       TOMLParserException when the document's syntax is incorrect
 */
TOMLDocument parseTOML(scope const(char)[] data, TOMLOptions options = TOMLOptions.none) @safe {
   return parseTOMLImpl!true(data, options);
}
/// ditto
TOMLDocument parseTOML(scope return string data, TOMLOptions options = TOMLOptions.none) @safe {
   return parseTOMLImpl!false(data, options);
}

private TOMLDocument parseTOMLImpl(bool dupData)(scope const(char)[] data, TOMLOptions options = TOMLOptions.none) @safe {
   size_t index = 0;

   /**
    * Throws a TOMLParserException at the current line and column.
    */
   void error(string message) {
      if (index >= data.length) {
         index = data.length;
      }
      size_t i, line, column;
      while (i < index) {
         if (data[i++] == '\n') {
            line++;
            column = 0;
         } else {
            column++;
         }
      }
      throw new TOMLParserException(message, line + 1, column);
   }

   /**
    * Throws a TOMLParserException throught the error function if
    * cond is false.
    */
   void enforceParser(bool cond, lazy string message) {
      if (!cond) {
         error(message);
      }
   }

   TOMLValue[string] _ret;
   auto current = (() @trusted => &_ret)();

   string[][] tableNames;

   void setImpl(scope TOMLValue[string]* table, string[] keys, string[] original, TOMLValue value) {
      auto ptr = keys[0] in *table;
      if (keys.length == 1) {
         // should not be there
         enforceParser(ptr is null, "Key is already defined");
         (*table)[keys[0]] = value;
      } else {
         // must be a table
         if (ptr !is null) {
            enforceParser((*ptr).type == TOML_TYPE.TABLE, join(original[0 .. $ - keys.length],
                  ".") ~ " is already defined and is not a table");
         } else {
            (*table)[keys[0]] = (TOMLValue[string]).init;
         }
         setImpl((() @trusted => &((*table)[keys[0]].table()))(), keys[1 .. $], original, value);
      }
   }

   void set(string[] keys, TOMLValue value) {
      setImpl(current, keys, keys, value);
   }

   /**
    * Removes whitespace characters and comments.
    * Return: whether there's still data to read
    */
   bool clear(bool clear_newline = true)() {
      static if (clear_newline) {
         enum chars = " \t\r\n";
      } else {
         enum chars = " \t\r";
      }
      if (index < data.length) {
         if (chars.canFind(data[index])) {
            index++;
            return clear!clear_newline();
         } else if (data[index] == '#') {
            // skip until end of line
            while (++index < data.length && data[index] != '\n') {
            }
            static if (clear_newline) {
               index++; // point at the next character
               return clear();
            } else {
               return true;
            }
         } else {
            return true;
         }
      } else {
         return false;
      }
   }

   /**
    * Indicates whether the given character is valid in an unquoted key.
    */
   bool isValidKeyChar(immutable char c) {
      return c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '-' || c == '_';
   }

   string readQuotedString(bool multiline)() {
      Appender!string ret;
      bool backslash = false;
      while (index < data.length) {
         static if (!multiline) {
            enforceParser(data[index] != '\n', "Unterminated quoted string");
         }
         if (backslash) {
            void readUnicode(size_t size)() {
               enforceParser(index + size < data.length, "Invalid UTF-8 sequence");
               char[4] buffer;
               immutable len = encode!(UseReplacementDchar.yes)(buffer, cast(dchar)to!ulong(data[index + 1 .. index + 1 + size], 16));
               ret.put(buffer[0 .. len].idup);
               index += size;
            }

            switch (data[index]) {
               case '"':
                  ret.put('"');
                  break;
               case '\\':
                  ret.put('\\');
                  break;
               case 'b':
                  ret.put('\b');
                  break;
               case 't':
                  ret.put('\t');
                  break;
               case 'n':
                  ret.put('\n');
                  break;
               case 'f':
                  ret.put('\f');
                  break;
               case 'r':
                  ret.put('\r');
                  break;
               case 'u':
                  readUnicode!4();
                  break;
               case 'U':
                  readUnicode!8();
                  break;
               default:
                  static if (multiline) {
                     index++;
                     if (clear()) {
                        // remove whitespace characters until next valid character
                        index--;
                        break;
                     }
                  }
                  enforceParser(false, "Invalid escape sequence: '\\" ~ (index < data.length ? [cast(immutable) data[index]] : "EOF") ~ "'");
            }
            backslash = false;
         } else {
            if (data[index] == '\\') {
               backslash = true;
            } else if (data[index] == '"') {
               // string closed
               index++;
               static if (multiline) {
                  // control that the string is really closed
                  if (index + 2 <= data.length && data[index .. index + 2] == "\"\"") {
                     index += 2;
                     return ret.data.stripFirstLine;
                  } else {
                     ret.put("\"");
                     continue;
                  }
               } else {
                  return ret.data;
               }
            } else {
               static if (multiline) {
                  mixin(doLineConversion);
               }
               ret.put(data[index]);
            }
         }
         index++;
      }
      error("Expecting \" (double quote) but found EOF");
      assert(0);
   }

   string readSimpleQuotedString(bool multiline)() {
      Appender!string ret;
      while (index < data.length) {
         static if (!multiline) {
            enforceParser(data[index] != '\n', "Unterminated quoted string");
         }
         if (data[index] == '\'') {
            // closed
            index++;
            static if (multiline) {
               // there must be 3 of them
               if (index + 2 <= data.length && data[index .. index + 2] == "''") {
                  index += 2;
                  return ret.data.stripFirstLine;
               } else {
                  ret.put("'");
               }
            } else {
               return ret.data;
            }
         } else {
            static if (multiline) {
               mixin(doLineConversion);
            }
            ret.put(data[index++]);
         }
      }
      error("Expecting ' (single quote) but found EOF");
      assert(0);
   }

   const(char)[] removeUnderscores(scope return const(char)[] strInput, scope const(char)[][] ranges...) @safe {
      bool checkRange(char c) {
         foreach (range; ranges) {
            if (c >= range[0] && c <= range[1]) {
               return true;
            }
         }
         return false;
      }

      auto str = strInput;

      bool underscore = false;
      for (size_t i = 0; i < str.length; i++) {
         if (str[i] == '_') {
            if (underscore || i == 0 || i == str.length - 1 || !checkRange(str[i - 1]) || !checkRange(str[i + 1])) {
               throw new Exception("");
            }
            str = str[0 .. i] ~ str[i + 1 .. $];
            i--;
            underscore = true;
         } else {
            underscore = false;
         }
      }
      return str;
   }

   TOMLValue readSpecial() {
      immutable start = index;
      while (index < data.length && !"\t\r\n,]}#".canFind(data[index])) {
         index++;
      }
      const(char)[] ret = data[start .. index].stripRight(' ');
      enforceParser(ret.length > 0, "Invalid empty value");
      switch (ret) {
         case "true":
            return TOMLValue(true);
         case "false":
            return TOMLValue(false);
         case "inf":
         case "+inf":
            return TOMLValue(double.infinity);
         case "-inf":
            return TOMLValue(-double.infinity);
         case "nan":
         case "+nan":
            return TOMLValue(double.nan);
         case "-nan":
            return TOMLValue(-double.nan);
         default:
            const original = ret;
            try {
               if (ret.length >= 10 && ret[4] == '-' && ret[7] == '-') {
                  // date or datetime
                  if (ret.length >= 19 && (ret[10] == 'T' || ret[10] == ' ') && ret[13] == ':' && ret[16] == ':') {
                     // datetime
                     if (ret[10] == ' ') {
                        ret = ret[0 .. 10] ~ 'T' ~ ret[11 .. $];
                     }
                     if (ret[19 .. $].canFind("-") || ret[$ - 1] == 'Z') {
                        // has timezone
                        return TOMLValue(SysTime.fromISOExtString(ret));
                     } else {
                        // is space allowed instead of T?
                        return TOMLValue(DateTime.fromISOExtString(ret));
                     }
                  } else {
                     return TOMLValue(Date.fromISOExtString(ret));
                  }
               } else if (ret.length >= 8 && ret[2] == ':' && ret[5] == ':') {
                  return TOMLValue(TimeOfDay.fromISOExtString(ret));
               }
               if (ret.length > 2 && ret[0] == '0') {
                  switch (ret[1]) {
                     case 'x':
                        return TOMLValue(to!long(removeUnderscores(ret[2 .. $], "09", "AZ", "az"), 16));
                     case 'o':
                        return TOMLValue(to!long(removeUnderscores(ret[2 .. $], "08"), 8));
                     case 'b':
                        return TOMLValue(to!long(removeUnderscores(ret[2 .. $], "01"), 2));
                     default:
                        break;
                  }
               }
               if (ret.canFind('.') || ret.canFind('e') || ret.canFind('E')) {
                  return TOMLValue(to!double(removeUnderscores(ret, "09")));
               } else {
                  if (ret[0] != '0' || ret.length == 1) {
                     return TOMLValue(to!long(removeUnderscores(ret, "09")));
                  }
               }
            } catch (Exception) {
            }
            // not a valid value at this point
            if (options & TOMLOptions.unquotedStrings) {
               static if (dupData)
                  return TOMLValue(original.idup);
               else
                  return TOMLValue((() @trusted => cast(string) original)());
            } else {
               error(text("Invalid type: '", original.idup, "'"));
            }
            assert(0);
      }
   }

   string readKey() {
      enforceParser(index < data.length, "Key declaration expected but found EOF");
      string ret;
      if (data[index] == '"') {
         index++;
         ret = readQuotedString!false();
      } else if (data[index] == '\'') {
         index++;
         ret = readSimpleQuotedString!false();
      } else {
         Appender!string appender;
         while (index < data.length && isValidKeyChar(data[index])) {
            appender.put(data[index++]);
         }
         ret = appender.data;
         enforceParser(ret.length != 0, "Key is empty or contains invalid characters");
      }
      return ret;
   }

   string[] readKeys() {
      string[] keys;
      index--;
      do {
         index++;
         clear!false();
         keys ~= readKey();
         clear!false();
      }
      while (index < data.length && data[index] == '.');
      enforceParser(keys.length != 0, "Key cannot be empty");
      return keys;
   }

   TOMLValue readValue() {
      if (index < data.length) {
         switch (data[index++]) {
            case '"':
               if (index + 2 <= data.length && data[index .. index + 2] == "\"\"") {
                  index += 2;
                  return TOMLValue(readQuotedString!true());
               } else {
                  return TOMLValue(readQuotedString!false());
               }
            case '\'':
               if (index + 2 <= data.length && data[index .. index + 2] == "''") {
                  index += 2;
                  return TOMLValue(readSimpleQuotedString!true());
               } else {
                  return TOMLValue(readSimpleQuotedString!false());
               }
            case '[':
               clear();
               TOMLValue[] array;
               bool comma = true;
               while (data[index] != ']') { //TODO check range error
                  enforceParser(comma, "Elements of the array must be separated with a comma");
                  array ~= readValue();
                  clear!false(); // spaces allowed between elements and commas
                  if (data[index] == ',') { //TODO check range error
                     index++;
                     comma = true;
                  } else {
                     comma = false;
                  }
                  clear(); // spaces and newlines allowed between elements
               }
               index++;
               return TOMLValue(array);
            case '{':
               clear!false();
               TOMLValue[string] table;
               bool comma = true;
               while (data[index] != '}') { //TODO check range error
                  enforceParser(comma, "Elements of the table must be separated with a comma");
                  auto keys = readKeys();
                  enforceParser(clear!false() && data[index++] == '=' && clear!false(), "Expected value after key declaration");
                  setImpl((() @trusted => &table)(), keys, keys, readValue());
                  enforceParser(clear!false(), "Expected ',' or '}' but found " ~ (index < data.length ? "EOL" : "EOF"));
                  if (data[index] == ',') {
                     index++;
                     comma = true;
                  } else {
                     comma = false;
                  }
                  clear!false();
               }
               index++;
               return TOMLValue(table);
            default:
               index--;
               break;
         }
      }
      return readSpecial();
   }

   void readKeyValue(string[] keys) {
      if (clear()) {
         enforceParser(data[index++] == '=', "Expected '=' after key declaration");
         if (clear!false()) {
            set(keys, readValue());
            // there must be nothing after the key/value declaration except comments and whitespaces
            if (clear!false())
               enforceParser(data[index] == '\n', "Invalid characters after value declaration: " ~ data[index]);
         } else {
            //TODO throw exception (missing value)
         }
      } else {
         //TODO throw exception (missing value)
      }
   }

   void next() @safe {
      if (data[index] == '[') {
         // reset base
         current = (() @trusted => &_ret)();
         index++;
         bool array = false;
         if (index < data.length && data[index] == '[') {
            index++;
            array = true;
         }
         string[] keys = readKeys();
         enforceParser(index < data.length && data[index++] == ']', "Invalid " ~ (array ? "array" : "table") ~ " key declaration");
         if (array) {
            enforceParser(index < data.length && data[index++] == ']', "Invalid array key declaration");
         }
         if (!array) {
            //TODO only enforce if every key is a table
            enforceParser(!tableNames.canFind(keys), "Table name has already been directly defined");
            tableNames ~= keys;
         }
         void update(string key, bool allowArray = true) {
            if (key !in *current) {
               set([key], TOMLValue(TOML_TYPE.TABLE));
            }
            auto ret = (*current)[key];
            if (ret.type == TOML_TYPE.TABLE) {
               current = (() @trusted => &((*current)[key].table()))();
            } else if (allowArray && ret.type == TOML_TYPE.ARRAY) {
               current = (() @trusted => &((*current)[key].array[$ - 1].table()))();
            } else {
               error("Invalid type");
            }
         }

         foreach (immutable key; keys[0 .. $ - 1]) {
            update(key);
         }
         if (array) {
            auto exist = keys[$ - 1] in *current;
            if (exist) {
               //TODO must be an array
               (*exist).array ~= TOMLValue(TOML_TYPE.TABLE);
            } else {
               set([keys[$ - 1]], TOMLValue([TOMLValue(TOML_TYPE.TABLE)]));
            }
            current = (() @trusted => &((*current)[keys[$ - 1]].array[$ - 1].table()))();
         } else {
            update(keys[$ - 1], false);
         }
      } else {
         readKeyValue(readKeys());
      }

   }

   while (clear()) {
      next();
   }

   return TOMLDocument(_ret);

}

private @property string stripFirstLine(string data) pure @safe {
   size_t i = 0;
   while (i < data.length && data[i] != '\n') {
      i++;
   }
   if (data[0 .. i].strip.length == 0) {
      return data[i + 1 .. $];
   } else {
      return data;
   }
}

version (Windows) {
   // convert posix's line ending to windows'
   private enum doLineConversion = q{
      if(data[index] == '\n' && index != 0 && data[index-1] != '\r') {
         index++;
         ret.put("\r\n");
         continue;
      }
   };
} else {
   // convert windows' line ending to posix's
   private enum doLineConversion = q{
      if(data[index] == '\r' && index + 1 < data.length && data[index+1] == '\n') {
         index += 2;
         ret.put("\n");
         continue;
      }
   };
}

/**
 * Exception thrown on generic TOML errors.
 */
class TOMLException : Exception {

   public this(string message, string file = __FILE__, size_t line = __LINE__) pure @safe scope {
      super(message, file, line);
   }

}

/**
 * Exception thrown during the parsing of TOML document.
 */
class TOMLParserException : TOMLException {

   private Tuple!(size_t, "line", size_t, "column") _position;

   public this(string message, size_t line, size_t column, string file = __FILE__, size_t _line = __LINE__) pure @safe scope {
      super(message ~ " (" ~ to!string(line) ~ ":" ~ to!string(column) ~ ")", file, _line);
      this._position.line = line;
      this._position.column = column;
   }

   /**
    * Gets the position (line and column) where the parsing expection
    * has occured.
    */
   public pure nothrow @property @safe @nogc auto position() scope {
      return this._position;
   }

}
