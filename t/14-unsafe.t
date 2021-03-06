# vi:filetype=

# The Unsafe API is a just hack,
# which will be obsolete once the Action API is implemented.

my $ExePath;
BEGIN {
    use OpenResty::Config;
    OpenResty::Config->init;
    unless ($OpenResty::Config{'test_suite.test_unsafe'}) {
        $skip = "Config option test_suite.test_unsafe is set to false.\n";
        return;
    }

    use FindBin;
    $ExePath = "$FindBin::Bin/../haskell/bin/restyscript";
    if (!-f $ExePath) {
        $skip = "$ExePath is not found.\n";
        return;
    }
    if (!-x $ExePath) {
        $skip = "$ExePath is not an executable.\n";
        return;
    }
};
use t::OpenResty $skip ? (skip_all => $skip) : ();

plan tests => 3 * blocks();

run_tests;

__DATA__

=== TEST 1: Delete existing models
--- request
DELETE /=/model.js?_user=$TestAccount&_password=$TestPass&_use_cookie=1
--- response
{"success":1}



=== TEST 2: drop tables
--- request
POST /=/unsafe/do
"drop table if exists _books cascade;
drop table if exists _cats;
drop table if exists _books2 cascade;"
--- response
{"success":1}



=== TEST 3: Create a DB table
--- request
POST /=/unsafe/do
"create table _books (id serial primary key, body text, num integer default 0);
create table _cats (id serial primary key, name text);"
--- response
{"success":1}



=== TEST 4: Insert some records
--- request
POST /=/unsafe/do
"insert into _books (body) values ('Larry Wall');
insert into _books (body) values ('Audrey Tang');
insert into _cats (name) values ('mimi');"
--- response
{"success":1}



=== TEST 5: .Select data
--- request
POST /=/unsafe/select
"select * from _books"
--- response
[
    {"body":"Larry Wall","num":"0","id":"1"},
    {"body":"Audrey Tang","num":"0","id":"2"}
]



=== TEST 6: CREATE FUNCTION
--- request
POST /=/unsafe/do
"CREATE OR REPLACE FUNCTION add_child() returns trigger as $$
    begin
        if NEW.id <> 0 then
            update _books set num=num+1 where id=1;
        END IF;
        return NEW;
    end;
$$ language plpgsql;"
--- response
{"success":1}



=== TEST 7: create tirgger
--- request
POST /=/unsafe/do
"CREATE TRIGGER add_child_t BEFORE INSERT ON _books FOR EACH ROW EXECUTE PROCEDURE add_child();"
--- response
{"success":1}



=== TEST 8: Insert some records
--- request
POST /=/unsafe/do
"insert into _books (body) values ('Larry Wall');
insert into _books (body) values ('Audrey Tang');
insert into _cats (name) values ('mimi');"
--- response
{"success":1}



=== TEST 9: .Select data
--- request
POST /=/unsafe/select
"select * from _books where id=1"
--- response
[{"body":"Larry Wall","num":"2","id":"1"}]



=== TEST 10: Create a DB table
--- request
POST /=/unsafe/do
"create table _books2 (id serial primary key, body text, num integer default 0);"
--- response
{"success":1}



=== TEST 11: CREATE PROC
--- request
POST /=/unsafe/do
"DROP FUNCTION if exists hello_world0(int,int);
CREATE OR REPLACE FUNCTION hello_world0(i int,j int) RETURNS _books AS $Q$
    declare
        tmp _books%ROWTYPE;
    begin
        select * into tmp from _books where id=i;
    return tmp;
    end;
$Q$LANGUAGE plpgsql;
GRANT EXECUTE ON FUNCTION \"hello_world0\" (int,int) to anonymous;
GRANT SELECT ON TABLE _books to anonymous;"
--- response
{"success":1}



=== TEST 12: select proc
--- request
GET /=/post/action/RunView/~/~?_data="select hello_world0(1,0)"
--- response
[{"hello_world0":"(1,\"Larry Wall\",2)"}]



=== TEST 13 CREATE PROC
--- request
POST /=/unsafe/do
"DROP FUNCTION if exists hello_world4(int,int);
CREATE OR REPLACE FUNCTION hello_world4(i int,j int) RETURNS setof _books2 AS $Q$
    declare
        tmp _books2%ROWTYPE;
    begin
        for tmp in select * from _books2 order by id loop
        return next tmp;
        end loop;
    return;
    end;
$Q$LANGUAGE plpgsql;
GRANT EXECUTE ON FUNCTION \"hello_world4\" (int,int) to anonymous;
GRANT SELECT ON TABLE _books2 to anonymous;"
--- response
{"success":1}



=== TEST 14: select * from proc() as ....
--- request
GET /=/post/action/RunView/~/~?_var=sss&_data="select * from hello_world4(1,0)"
--- response
sss=[];



=== TEST 15: drop tables
--- request
POST /=/unsafe/do
"drop table if exists _books cascade;
drop table if exists _books2 cascade;
drop table if exists _cats;"
--- response
{"success":1}



=== TEST 16: logout
--- request
GET /=/logout
--- response
{"success":1}

