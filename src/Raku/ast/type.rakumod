# Some kind of type (done by all kinds of things that result in a type).
class RakuAST::Type is RakuAST::Term is RakuAST::Meta {
    # Checks if the type is statically known to be some particular type
    # (provided as the type object, not as another RakuAST node).
    method is-known-to-be(Mu $type) {
        nqp::die('Expected a type object') if nqp::isconcrete($type);
        if nqp::istype(self, RakuAST::Lookup) && self.is-resolved {
            my $resolution := self.resolution;
            if nqp::istype($resolution, RakuAST::CompileTimeValue) {
                return nqp::istype($resolution.compile-time-value, $type);
            }
        }
        0
    }
}

# A simple type name, e.g. Int, Foo::Bar, etc.
class RakuAST::Type::Simple is RakuAST::Type is RakuAST::Lookup {
    has RakuAST::Name $.name;

    method new(RakuAST::Name $name) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::Type::Simple, '$!name', $name);
        $obj
    }

    method resolve-with(RakuAST::Resolver $resolver) {
        my $resolved := $resolver.resolve-name-constant($!name);
        if $resolved {
            self.set-resolution($resolved);
        }
        Nil
    }

    method PRODUCE-META-OBJECT() {
        self.resolution.compile-time-value
    }

    method IMPL-EXPR-QAST(RakuAST::IMPL::QASTContext $context) {
        my $value := self.resolution.compile-time-value;
        $context.ensure-sc($value);
        QAST::WVal.new( :$value )
    }

    method IMPL-CAN-INTERPRET() {
        self.is-resolved && nqp::istype(self.resolution, RakuAST::CompileTimeValue)
    }

    method IMPL-INTERPRET(RakuAST::IMPL::InterpContext $ctx) {
        self.resolution.compile-time-value
    }
}

# A simple type name, e.g. Int, Foo::Bar, etc. that should be looked up in the
# setting.
class RakuAST::Type::Setting is RakuAST::Type::Simple {
    # TODO limit lookup to setting
}

class RakuAST::Type::Coercion is RakuAST::Type is RakuAST::Lookup {
    has RakuAST::Name $.name;
    has RakuAST::Type $!constraint;

    method new(RakuAST::Name $name, Mu $constraint) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::Type::Coercion, '$!name', $name);
        nqp::bindattr($obj, RakuAST::Type::Coercion, '$!constraint', $constraint);
        $obj
    }

    method resolve-with(RakuAST::Resolver $resolver) {
        my $resolved := $resolver.resolve-name-constant($!name);
        if $resolved {
            self.set-resolution($resolved);
        }
        Nil
    }

    method PRODUCE-META-OBJECT() {
        Perl6::Metamodel::CoercionHOW.new_type(
            self.resolution.compile-time-value,
            $!constraint.meta-object,
        );
    }

    method IMPL-EXPR-QAST(RakuAST::IMPL::QASTContext $context) {
        my $value := self.meta-object;
        $context.ensure-sc($value);
        QAST::WVal.new( :$value )
    }

    method IMPL-CAN-INTERPRET() {
        self.is-resolved && nqp::istype(self.resolution, RakuAST::CompileTimeValue)
    }

    method IMPL-INTERPRET(RakuAST::IMPL::InterpContext $ctx) {
        self.meta-object
    }

    method visit-children(Code $visitor) {
        $visitor($!constraint);
    }
}
