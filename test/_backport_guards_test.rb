require './test/test_helper'
$bogus = []

module Kernel
  def require_with_bogus_extension(lib)
    $bogus << lib
    require_without_bogus_extension(lib)
  end
  alias_method :require_without_bogus_extension, :require
  alias_method :require, :require_with_bogus_extension

  if defined? BasicObject and BasicObject.superclass
    BasicObject.send :undef_method, :require
    BasicObject.send :undef_method, :require_with_bogus_extension
  end
end

class AAA_TestBackportGuards < Test::Unit::TestCase
  def setup
    # Override test/helper's definition, do not require backports yet
  end

  EXCLUDE = %w[require] # Overriden in all circumstances to load the std-lib
  EXCLUDE.map!(&:to_sym) if instance_methods.first.is_a?(Symbol)

  def class_signature(klass)
    Hash[
      (klass.instance_methods - EXCLUDE).map{|m| [m, klass.instance_method(m)] } +
      (klass.methods - EXCLUDE).map{|m| [".#{m}", klass.method(m) ]}
    ]
  end

  CLASSES = [Array, Binding, Dir, Enumerable, Fixnum, Float, GC,
      Hash, Integer, IO, Kernel, Math, MatchData, Method, Module, Numeric,
      ObjectSpace, Proc, Process, Range, Regexp, String, Struct, Symbol] +
    [ENV, ARGF].map{|obj| class << obj; self; end }

  case RUBY_VERSION
    when '1.8.6'
    when '1.8.7'
      CLASSES << Enumerable::Enumerator
    else
      CLASSES << Enumerator
  end

  def digest
    Hash[
      CLASSES.map { |klass| [klass, class_signature(klass)] }
    ]
  end

  def digest_delta(before, after)
    delta = {}
    before.each do |klass, methods|
      compare = after[klass]
      d = methods.map do |name, unbound|
        name unless unbound == compare[name]
      end
      d.compact!
      delta[klass] = d unless d.empty?
    end
    delta unless delta.empty?
  end

  # Order super important!
  def test__1_abbrev_can_be_required_before_backports
    assert require 'abbrev'
    assert !$LOADED_FEATURES.include?('backports')
  end

  # Order super important!
  def test__2_backports_wont_override_unnecessarily
    before = digest
    require "./lib/backports/#{RUBY_VERSION}"
    after = digest
    assert_nil digest_delta(before, after)
    unless RUBY_VERSION == "2.0.0"
      require "./lib/backports"
      after = digest
      assert !digest_delta(before, after).nil?
    end
  end

  def test_setlib_load_correctly_after_requiring_backports
    path = File.expand_path("../../lib/backports/1.9.2/stdlib/matrix.rb", __FILE__)
    assert_equal false,  $LOADED_FEATURES.include?(path)
    assert_equal true,  require('matrix')
    assert_equal true,  $bogus.include?("matrix")
    assert_equal true,  $LOADED_FEATURES.include?(path)
    assert_equal false, require('matrix')
  end

  def test_setlib_load_correctly_before_requiring_backports_test
    assert_equal true,  $bogus.include?("abbrev")
    path = File.expand_path("../../lib/backports/2.0.0/stdlib/abbrev.rb", __FILE__)
    assert_equal true,  $LOADED_FEATURES.include?(path)
    assert_equal false, require('abbrev')
  end

  def test_backports_does_not_interfere_for_libraries_without_backports_test
    assert_equal true,  require('scanf')
    assert_equal false, require('scanf')
  end

  def test_load_correctly_new_libraries_test
    path = File.expand_path("../../lib/backports/2.0.0/stdlib/fake_stdlib_lib.rb", __FILE__)
    assert_equal false, $LOADED_FEATURES.include?(path)
    assert_equal true,  require('fake_stdlib_lib')
    assert_equal true,  $LOADED_FEATURES.include?(path)
    assert_equal false, require('fake_stdlib_lib')
  end
end

