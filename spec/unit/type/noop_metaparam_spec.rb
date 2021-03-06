#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/type'

describe Oregano::Type.type(:file).attrclass(:noop) do
  include OreganoSpec::Files

  before do
    Oregano.settings.stubs(:use)
    @file = Oregano::Type.newfile :path => make_absolute("/what/ever")
  end

  it "should accept true as a value" do
    expect { @file[:noop] = true }.not_to raise_error
  end

  it "should accept false as a value" do
    expect { @file[:noop] = false }.not_to raise_error
  end

  describe "when set on a resource" do
    it "should default to the :noop setting" do
      Oregano[:noop] = true
      expect(@file.noop).to eq(true)
    end

    it "should prefer true values from the attribute" do
      @file[:noop] = true
      expect(@file.noop).to be_truthy
    end

    it "should prefer false values from the attribute" do
      @file[:noop] = false
      expect(@file.noop).to be_falsey
    end
  end
end
