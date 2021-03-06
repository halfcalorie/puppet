#! /usr/bin/env ruby
require 'spec_helper'

describe Oregano::Util::Warnings do
  before(:all) do
    @msg1 = "booness"
    @msg2 = "more booness"
  end

  before(:each) do
    Oregano.debug = true
  end

  after (:each) do
    Oregano.debug = false
  end

  {:notice => "notice_once", :warning => "warnonce", :debug => "debug_once"}.each do |log, method|
    describe "when registring '#{log}' messages" do
      it "should always return nil" do
        expect(Oregano::Util::Warnings.send(method, @msg1)).to be(nil)
      end

      it "should issue a warning" do
        Oregano.expects(log).with(@msg1)
        Oregano::Util::Warnings.send(method, @msg1)
      end

      it "should issue a warning exactly once per unique message" do
        Oregano.expects(log).with(@msg1).once
        Oregano::Util::Warnings.send(method, @msg1)
        Oregano::Util::Warnings.send(method, @msg1)
      end

      it "should issue multiple warnings for multiple unique messages" do
        Oregano.expects(log).times(2)
        Oregano::Util::Warnings.send(method, @msg1)
        Oregano::Util::Warnings.send(method, @msg2)
      end
    end
  end

  after(:each) do
    Oregano::Util::Warnings.clear_warnings
  end
end
