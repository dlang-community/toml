import std.stdio;

import toml;
import core.stdc.stdlib;
int main() {
   string data;
   readf(" %s", &data);
   try {
      parseTOML(data);
      return 0;
   } catch (Exception e) {
      stdout.writefln(e.msg);
      stderr.writefln(e.msg);
      return -1;
   }
}
