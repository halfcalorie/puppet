#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/ssl/certificate'

class TestCertificate < Oregano::SSL::Base
    wraps(Oregano::SSL::Certificate)
end

describe Oregano::SSL::Certificate do
  before :each do
    @base = TestCertificate.new("name")
    @class = TestCertificate
  end

  describe "when creating new instances" do
    it "should fail if given an object that is not an instance of the wrapped class" do
      obj = stub 'obj', :is_a? => false
      expect { @class.from_instance(obj) }.to raise_error(ArgumentError)
    end

    it "should fail if a name is not supplied and can't be determined from the object" do
      obj = stub 'obj', :is_a? => true
      expect { @class.from_instance(obj) }.to raise_error(ArgumentError)
    end

    it "should determine the name from the object if it has a subject" do
      obj = stub 'obj', :is_a? => true, :subject => '/CN=foo'

      inst = stub 'base'
      inst.expects(:content=).with(obj)

      @class.expects(:new).with('foo').returns inst
      @class.expects(:name_from_subject).with('/CN=foo').returns('foo')

      expect(@class.from_instance(obj)).to eq(inst)
    end
  end

  describe "when determining a name from a certificate subject" do
    it "should extract only the CN and not any other components" do
      subject = stub 'sub'
      Oregano::Util::SSL.expects(:cn_from_subject).with(subject).returns 'host.domain.com'
      expect(@class.name_from_subject(subject)).to eq('host.domain.com')
    end
  end

  describe "when initializing wrapped class from a file with #read" do
    it "should open the file with ASCII encoding" do
      path = '/foo/bar/cert'
      Oregano::SSL::Base.stubs(:valid_certname).returns(true)
      Oregano::FileSystem.expects(:read).with(path, :encoding => Encoding::ASCII).returns("bar")
      @base.read(path)
    end
  end

  describe "#digest_algorithm" do
    let(:content) { stub 'content' }
    let(:base) {
      b = Oregano::SSL::Base.new('base')
      b.content = content
      b
    }

    # Some known signature algorithms taken from RFC 3279, 5758, and browsing
    # objs_dat.h in openssl
    {
      'md5WithRSAEncryption' => 'md5',
      'sha1WithRSAEncryption' => 'sha1',
      'md4WithRSAEncryption' => 'md4',
      'sha256WithRSAEncryption' => 'sha256',
      'ripemd160WithRSA' => 'ripemd160',
      'ecdsa-with-SHA1' => 'sha1',
      'ecdsa-with-SHA224' => 'sha224',
      'ecdsa-with-SHA256' => 'sha256',
      'ecdsa-with-SHA384' => 'sha384',
      'ecdsa-with-SHA512' => 'sha512',
      'dsa_with_SHA224' => 'sha224',
      'dsaWithSHA1' => 'sha1',
    }.each do |signature, digest|
      it "returns '#{digest}' for signature algorithm '#{signature}'" do
        content.stubs(:signature_algorithm).returns(signature)
        expect(base.digest_algorithm).to eq(digest)
      end
    end

    it "raises an error on an unknown signature algorithm" do
      content.stubs(:signature_algorithm).returns("nonsense")
      expect {
        base.digest_algorithm
      }.to raise_error(Oregano::Error, "Unknown signature algorithm 'nonsense'")
    end
  end
end
