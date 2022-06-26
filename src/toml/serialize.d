module toml.serialize;

import toml.toml;

import std.array;
import std.sumtype;
import std.traits;

// UDAs:
struct tomlName { string name; }
enum tomlIgnored;
// ---

string serializeTOML(T)(T value)
{
	auto ret = appender!string;
	serializeTOML(value, ret);
	return ret.data;
}

void serializeTOML(T, Output)(T value, ref Output output)
{
	serializeTOML(value, output, "", "");
}

private:

// indentation increase per level
enum oneIndentLevel = "  ";

template fieldName(alias field)
{
	enum nameUDAs = getUDAs!(field, tomlName);
	static if (nameUDAs.length == 1)
		enum fieldName = nameUDAs[0].name;
	else static if (nameUDAs.length == 0)
		enum fieldName = __traits(identifier, field);
	else
		static assert(false, "Field " ~ __traits(identifier, field) ~ " has multiple @tomlName UDAs");
}

void serializeTOML(T, Output)(T value, ref Output output, string indent, string group)
	if (isPlainStruct!T)
{
	foreach (i, ref v; value.tupleof)
	{{
		static if (isValueSerializable!(typeof(v))
			&& getUDAs!(value.tupleof[i], tomlIgnored).length == 0
			&& !isStructArray!(typeof(v)))
		{
			enum prefix = fieldName!(value.tupleof[i]) ~ " = ";
			if (indent.length)
				output.put(indent);
			output.put(prefix);
			serializeTOMLValue(v, output);
			output.put("\n");
		}
	}}

	foreach (i, ref v; value.tupleof)
	{{
		static if (isValueSerializable!(typeof(v))
			&& getUDAs!(value.tupleof[i], tomlIgnored).length == 0
			&& isStructArray!(typeof(v)))
		{
			enum prefix = fieldName!(value.tupleof[i]) ~ "]]\n";
			auto deeperIndent = v.length ? indent ~ oneIndentLevel : null;
			auto deepGroup = group ~ (fieldName!(value.tupleof[i]) ~ ".");
			foreach (item; v)
			{
				output.put("\n");
				if (indent.length)
					output.put(indent);
				output.put("[[");
				if (group.length)
					output.put(group);
				output.put(prefix);
				serializeTOML(item, output, deeperIndent, deepGroup);
			}
		}
	}}

	foreach (i, ref v; value.tupleof)
	{{
		static if (!isValueSerializable!(typeof(v))
			&& getUDAs!(value.tupleof[i], tomlIgnored).length == 0)
		{
			enum prefix = fieldName!(value.tupleof[i]) ~ "]\n";
			output.put("\n");
			if (indent.length)
				output.put(indent);
			output.put("[");
			if (group.length)
				output.put(group);
			output.put(prefix);
			serializeTOML(v, output, indent ~ oneIndentLevel,  group ~ (fieldName!(value.tupleof[i]) ~ "."));
		}
	}}
}

void serializeTOML(T, Output)(T value, ref Output output, string indent, string group)
	if (is(T == SumType!Types, Types...))
{
	if (indent.length)
		output.put(indent);
	output.put("kind = ");

	value.match!(
		(part) {
			serializeTOMLValue(typeof(part).stringof, output);
			output.put("\n");
			if (indent.length)
				output.put(indent);

			static if (isValueSerializable!(typeof(part)))
			{
				static if (isStructArray!(typeof(v)))
				{
					auto deeperIndent = indent ~ oneIndentLevel;
					auto deepGroup = group ~ "value.";
					foreach (arritem; part)
					{
						output.put("[[");
						if (group.length)
							output.put(group);
						output.put("value]]\n");
						serializeTOML(arritem, output, deeperIndent,  deepGroup);
					}
				}
				else
				{
					output.put("value = ");
					serializeTOMLValue(part, output);
					output.put("\n");
				}
			}
			else
			{
				output.put("[");
				if (group.length)
					output.put(group);
				output.put("value]\n");
				serializeTOML(part, output, indent ~ oneIndentLevel,  group ~ "value.");
			}
		}
	);
}

// format struct arrays as expanded fields
enum isStructArray(T) = is(T == U[], U) && isPlainStruct!U;

enum isPlainStruct(T) = is(T == struct) && !is(T == SumType!U, U...);

enum isValueSerializable(T) = !is(T == struct);

void serializeTOMLValue(T, Output)(T value, ref Output output)
{
	static if (__traits(compiles, { auto v = TOMLValue(value); }))
	{
		auto v = TOMLValue(value);
		v.append(output);
	}
	else
		static assert(false, "TODO: serialize value type " ~ T.stringof ~ " not implemented");
}

unittest
{
	struct Database
	{
		string host;
		string database;
		int port;
	}

	struct User
	{
		string name;
		@tomlIgnored
		string password;
		@tomlName("id")
		int count;
	}

	struct Config
	{
		string token;
		Database database;
		int[] ports;
		User[] users;
	}

	Config config = {
		token: "bot123",
		ports: [1337, 4242, 5555],
		users: [
			User("Alice", "123", 1),
			User("Bob", "456", 2),
		],
		database: Database("localhost", "mybot", 8080)
	};

	auto str = serializeTOML(config);

	assert(str == `token = "bot123"
ports = [1337, 4242, 5555]

[[users]]
  name = "Alice"
  id = 1

[[users]]
  name = "Bob"
  id = 2

[database]
  host = "localhost"
  database = "mybot"
  port = 8080
`, str);
}
