require 'spec_helper'
require 'oregano/file_system'
require 'oregano/module_tool/applications'
require 'oregano_spec/modules'

describe Oregano::ModuleTool::Applications::Builder do
  include OreganoSpec::Files

  let(:path)         { tmpdir("working_dir") }
  let(:module_name)  { 'mymodule-mytarball' }
  let(:version)      { '0.0.1' }
  let(:release_name) { "#{module_name}-#{version}" }
  let(:tarball)      { File.join(path, 'pkg', release_name) + ".tar.gz" }
  let(:builder)      { Oregano::ModuleTool::Applications::Builder.new(path) }

  shared_examples "a packagable module" do
    def target_exists?(file)
      File.exist?(File.join(path, "pkg", "#{module_name}-#{version}", file))
    end

    def build
      tarrer = mock('tarrer')
      Oregano::ModuleTool::Tar.expects(:instance).returns(tarrer)
      Dir.expects(:chdir).with(File.join(path, 'pkg')).yields
      tarrer.expects(:pack).with(release_name, tarball)

      builder.run
    end

      def create_regular_files
      Oregano::FileSystem.touch(File.join(path, '.dotfile'))
      Oregano::FileSystem.touch(File.join(path, 'file.foo'))
      Oregano::FileSystem.touch(File.join(path, 'REVISION'))
      Oregano::FileSystem.touch(File.join(path, '~file'))
      Oregano::FileSystem.touch(File.join(path, '#file'))
      Oregano::FileSystem.mkpath(File.join(path, 'pkg'))
      Oregano::FileSystem.mkpath(File.join(path, 'coverage'))
      Oregano::FileSystem.mkpath(File.join(path, 'sub'))
      Oregano::FileSystem.touch(File.join(path, 'sub/.dotfile'))
      Oregano::FileSystem.touch(File.join(path, 'sub/file.foo'))
      Oregano::FileSystem.touch(File.join(path, 'sub/REVISION'))
      Oregano::FileSystem.touch(File.join(path, 'sub/~file'))
      Oregano::FileSystem.touch(File.join(path, 'sub/#file'))
      Oregano::FileSystem.mkpath(File.join(path, 'sub/pkg'))
      Oregano::FileSystem.mkpath(File.join(path, 'sub/coverage'))
    end

    def create_symlinks
      Oregano::FileSystem.touch(File.join(path, 'symlinkedfile'))
      Oregano::FileSystem.symlink(File.join(path, 'symlinkedfile'), File.join(path, 'symlinkfile'))
    end

    def create_ignored_files
      Oregano::FileSystem.touch(File.join(path, 'gitignored.foo'))
      Oregano::FileSystem.mkpath(File.join(path, 'gitdirectory/sub'))
      Oregano::FileSystem.touch(File.join(path, 'gitdirectory/gitartifact'))
      Oregano::FileSystem.touch(File.join(path, 'gitdirectory/gitimportantfile'))
      Oregano::FileSystem.touch(File.join(path, 'gitdirectory/sub/artifact'))
      Oregano::FileSystem.touch(File.join(path, "git\u16A0\u16C7\u16BB"))
      Oregano::FileSystem.touch(File.join(path, 'pmtignored.foo'))
      Oregano::FileSystem.mkpath(File.join(path, 'pmtdirectory/sub'))
      Oregano::FileSystem.touch(File.join(path, 'pmtdirectory/pmtimportantfile'))
      Oregano::FileSystem.touch(File.join(path, 'pmtdirectory/pmtartifact'))
      Oregano::FileSystem.touch(File.join(path, 'pmtdirectory/sub/artifact'))
      Oregano::FileSystem.touch(File.join(path, "pmt\u16A0\u16C7\u16BB"))
    end

    def create_pmtignore_file
      File.open(File.join(path, '.pmtignore'), 'w', 0600, :encoding => 'utf-8') do |f|
        f << <<-PMTIGNORE
pmtignored.*
pmtdirectory/sub/**
pmtdirectory/pmt*
!pmtimportantfile
pmt\u16A0\u16C7\u16BB
PMTIGNORE
      end
    end

    def create_gitignore_file
      File.open(File.join(path, '.gitignore'), 'w', 0600, :encoding => 'utf-8') do |f|
        f << <<-GITIGNORE
gitignored.*
gitdirectory/sub/**
gitdirectory/git*
!gitimportantfile
git\u16A0\u16C7\u16BB
GITIGNORE
      end
    end

    def create_symlink_gitignore_file
      File.open(File.join(path, '.gitignore'), 'w', 0600, :encoding => 'utf-8') do |f|
        f << <<-GITIGNORE
symlinkfile
    GITIGNORE
      end
    end

    shared_examples "regular files are present" do
      it "has metadata" do
        expect(target_exists?('metadata.json')).to eq true
      end

      it "has checksums" do
        expect(target_exists?('checksums.json')).to eq true
      end

      it "copies regular files" do
        expect(target_exists?('file.foo')).to eq true
      end
    end

    shared_examples "default artifacts are removed in module dir but not in subdirs" do
      it "ignores dotfiles" do
        expect(target_exists?('.dotfile')).to eq false
        expect(target_exists?('sub/.dotfile')).to eq true
      end

      it "does not have .gitignore" do
        expect(target_exists?('.gitignore')).to eq false
      end

      it "does not have .pmtignore" do
        expect(target_exists?('.pmtignore')).to eq false
      end

      it "does not have pkg" do
        expect(target_exists?('pkg')).to eq false
        expect(target_exists?('sub/pkg')).to eq true
      end

      it "does not have coverage" do
        expect(target_exists?('coverage')).to eq false
        expect(target_exists?('sub/coverage')).to eq true
      end

      it "does not have REVISION" do
        expect(target_exists?('REVISION')).to eq false
        expect(target_exists?('sub/REVISION')).to eq true
      end

      it "does not have ~files" do
        expect(target_exists?('~file')).to eq false
        expect(target_exists?('sub/~file')).to eq true
      end

      it "does not have #files" do
        expect(target_exists?('#file')).to eq false
        expect(target_exists?('sub/#file')).to eq true
      end
    end

    shared_examples "gitignored files are present" do
      it "leaves regular files" do
        expect(target_exists?('gitignored.foo')).to eq true
      end

      it "leaves UTF-8 files" do
        expect(target_exists?("git\u16A0\u16C7\u16BB")).to eq true
      end

      it "leaves directories" do
        expect(target_exists?('gitdirectory')).to eq true
      end

      it "leaves files in directories" do
        expect(target_exists?('gitdirectory/gitartifact')).to eq true
      end

      it "leaves exceptional files" do
        expect(target_exists?('gitdirectory/gitimportantfile')).to eq true
      end

      it "leaves subdirectories" do
        expect(target_exists?('gitdirectory/sub')).to eq true
      end

      it "leaves files in subdirectories" do
        expect(target_exists?('gitdirectory/sub/artifact')).to eq true
      end
    end

    shared_examples "gitignored files are not present" do
      it "ignores regular files" do
        expect(target_exists?('gitignored.foo')).to eq false
      end

      it "ignores UTF-8 files" do
        expect(target_exists?("git\u16A0\u16C7\u16BB")).to eq false
      end

      it "ignores directories" do
        expect(target_exists?('gitdirectory')).to eq true
      end

      it "ignores files in directories" do
        expect(target_exists?('gitdirectory/gitartifact')).to eq false
      end

      it "copies exceptional files" do
        expect(target_exists?('gitdirectory/gitimportantfile')).to eq true
      end

      it "ignores subdirectories" do
        expect(target_exists?('gitdirectory/sub')).to eq false
      end

      it "ignores files in subdirectories" do
        expect(target_exists?('gitdirectory/sub/artifact')).to eq false
      end
    end

    shared_examples "pmtignored files are present" do
      it "leaves regular files" do
        expect(target_exists?('pmtignored.foo')).to eq true
      end

      it "leaves UTF-8 files" do
        expect(target_exists?("pmt\u16A0\u16C7\u16BB")).to eq true
      end

      it "leaves directories" do
        expect(target_exists?('pmtdirectory')).to eq true
      end

      it "ignores files in directories" do
        expect(target_exists?('pmtdirectory/pmtartifact')).to eq true
      end

      it "leaves exceptional files" do
        expect(target_exists?('pmtdirectory/pmtimportantfile')).to eq true
      end

      it "leaves subdirectories" do
        expect(target_exists?('pmtdirectory/sub')).to eq true
      end

      it "leaves files in subdirectories" do
        expect(target_exists?('pmtdirectory/sub/artifact')).to eq true
      end
    end

    shared_examples "pmtignored files are not present" do
      it "ignores regular files" do
        expect(target_exists?('pmtignored.foo')).to eq false
      end

      it "ignores UTF-8 files" do
        expect(target_exists?("pmt\u16A0\u16C7\u16BB")).to eq false
      end

      it "ignores directories" do
        expect(target_exists?('pmtdirectory')).to eq true
      end

      it "copies exceptional files" do
        expect(target_exists?('pmtdirectory/pmtimportantfile')).to eq true
      end

      it "ignores files in directories" do
        expect(target_exists?('pmtdirectory/pmtartifact')).to eq false
      end

      it "ignores subdirectories" do
        expect(target_exists?('pmtdirectory/sub')).to eq false
      end

      it "ignores files in subdirectories" do
        expect(target_exists?('pmtdirectory/sub/artifact')).to eq false
      end
    end

    context "with no ignore files" do
      before :each do
        create_regular_files
        create_ignored_files

        build
      end

      it_behaves_like "regular files are present"
      it_behaves_like "default artifacts are removed in module dir but not in subdirs"
      it_behaves_like "pmtignored files are present"
      it_behaves_like "gitignored files are present"
    end

    context "with .gitignore file" do
      before :each do
        create_regular_files
        create_ignored_files
        create_gitignore_file

        build
      end

      it_behaves_like "regular files are present"
      it_behaves_like "default artifacts are removed in module dir but not in subdirs"
      it_behaves_like "pmtignored files are present"
      it_behaves_like "gitignored files are not present"
    end

    context "with .pmtignore file" do
      before :each do
        create_regular_files
        create_ignored_files
        create_pmtignore_file

        build
      end

      it_behaves_like "regular files are present"
      it_behaves_like "default artifacts are removed in module dir but not in subdirs"
      it_behaves_like "gitignored files are present"
      it_behaves_like "pmtignored files are not present"
    end

    context "with .pmtignore and .gitignore file" do
      before :each do
        create_regular_files
        create_ignored_files
        create_pmtignore_file
        create_gitignore_file

        build
      end

      it_behaves_like "regular files are present"
      it_behaves_like "default artifacts are removed in module dir but not in subdirs"
      it_behaves_like "gitignored files are present"
      it_behaves_like "pmtignored files are not present"
    end

    context "with unignored symlinks", :if => Oregano.features.manages_symlinks? do
      before :each do
        create_regular_files
        create_symlinks
        create_ignored_files
      end

      it "give an error about symlinks" do
        expect { builder.run }.to raise_error(Oregano::ModuleTool::Errors::ModuleToolError, /Found symlinks/)
      end
    end

    context "with .gitignore file and ignored symlinks", :if => Oregano.features.manages_symlinks? do
      before :each do
        create_regular_files
        create_symlinks
        create_ignored_files
        create_symlink_gitignore_file
      end

      it "does not give an error about symlinks" do
        expect { build }.not_to raise_error
      end
    end
  end

  context 'with metadata.json' do
    # different UTF-8 widths
    # 1-byte A
    # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
    # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
    # 4-byte 𠜎 - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
    MIXED_UTF8 = "A\u06FF\u16A0\u{2070E}" # Aۿᚠ𠜎

    before :each do
      File.open(File.join(path, 'metadata.json'), 'w') do |f|
        f.puts({
          "name" => "#{module_name}",
          "version" => "#{version}",
          "source" => "https://github.com/testing/#{module_name}",
          "author" => "testing",
          "license" => "Apache License Version 2.0",
          "summary" => "#{MIXED_UTF8}",
          "description" => "This module can be used for basic testing",
          "project_page" => "https://github.com/testing/#{module_name}"
        }.to_json)
      end
    end

    it_behaves_like "a packagable module"

    it "does not package with a symlink", :if => Oregano.features.manages_symlinks? do
      FileUtils.touch(File.join(path, 'tempfile'))
      Oregano::FileSystem.symlink(File.join(path, 'tempfile'), File.join(path, 'tempfile2'))

      expect {
        builder.run
      }.to raise_error Oregano::ModuleTool::Errors::ModuleToolError, /symlinks/i
    end

    it "does not package with a symlink in a subdir", :if => Oregano.features.manages_symlinks? do
      FileUtils.mkdir(File.join(path, 'manifests'))
      FileUtils.touch(File.join(path, 'manifests/tempfile.pp'))
      Oregano::FileSystem.symlink(File.join(path, 'manifests/tempfile.pp'), File.join(path, 'manifests/tempfile2.pp'))

      expect {
        builder.run
      }.to raise_error Oregano::ModuleTool::Errors::ModuleToolError, /symlinks/i
    end

    it "writes UTF-8 metdata correctly" do
      # file is written initially in before block, then by builders write_json method
      builder.run
      metadata_path = File.join(path, 'metadata.json')
      summary = JSON.parse(Oregano::FileSystem.read(metadata_path, :encoding => Encoding::UTF_8))["summary"]
      expect(summary).to eq(MIXED_UTF8)
    end
  end

  context 'with metadata.json containing checksums' do
    before :each do
      File.open(File.join(path, 'metadata.json'), 'w') do |f|
        f.puts({
          "name" => "#{module_name}",
          "version" => "#{version}",
          "source" => "https://github.com/testing/#{module_name}",
          "author" => "testing",
          "license" => "Apache License Version 2.0",
          "summary" => "Oregano testing module",
          "description" => "This module can be used for basic testing",
          "project_page" => "https://github.com/testing/#{module_name}",
          "checksums" => {"README.md" => "deadbeef"}
        }.to_json)
      end
    end

    it_behaves_like "a packagable module"
  end
end
