# linkclean_functions_spec.rb
require "rspec"
require "json"
require_relative "../linkclean_functions"

RSpec.describe "URL Cleaning Functions" do
  describe "#clean_url" do
    context "with Amazon URLs" do
      it "cleans Amazon search URLs" do
        url = "https://www.amazon.com/s?k=ruby+book&ref=nb_sb_noss_2"
        expect(clean_url(url)).to eq("https://www.amazon.com/s?k=ruby+book")
      end

      it "cleans Amazon product URLs" do
        url = "https://www.amazon.com/Ruby-Programming-Language-David-Flanagan/dp/0596516177?psc=1"
        expect(clean_url(url)).to eq("https://www.amazon.com/Ruby-Programming-Language-David-Flanagan/dp/0596516177")
      end

      it "handles Amazon smile URLs" do
        url = "https://smile.amazon.com/gp/product/B08C4KWM9T/ref=ppx_yo_dt_b_asin_title_o00_s00"
        expect(clean_url(url)).to eq("https://smile.amazon.com/gp/product/B08C4KWM9T")
      end
    end

    context "with generic URLs" do
      it "removes mobile prefixes" do
        url = "https://m.example.com/page"
        expect(clean_url(url)).to eq("https://example.com/page")
      end

      it "removes touch prefixes" do
        url = "https://touch.example.com/page"
        expect(clean_url(url)).to eq("https://example.com/page")
      end

      it "removes query parameters" do
        url = "https://example.com/page?utm_source=twitter&ref=123"
        expect(clean_url(url)).to eq("https://example.com/page")
      end
    end
  end

  describe "#follow_redirects" do
    it "follows URL redirects" do
      # Mock the external command with a known result
      allow(Open3).to receive(:capture2)
        .with("curl", "--silent", "--head", "--location", "--globoff", "--output", File::NULL,
          "--write-out", "%{url_effective}", "https://shortlink.com/abc123")
        .and_return(["https://final-destination.com", nil])

      url = "https://shortlink.com/abc123"
      expect(follow_redirects(url)).to eq("https://final-destination.com")
    end
  end

  describe "#clipboard_url" do
    it "retrieves URL from clipboard database" do
      # Mock the sqlite3 command
      allow(Open3).to receive(:capture2)
        .with("/usr/bin/sqlite3", "#{ENV["HOME"]}/Library/Application Support/Alfred/Databases/clipboard.alfdb",
          'SELECT item FROM (SELECT item,MAX(ts) FROM clipboard WHERE dataType = 0 AND item LIKE "http%");')
        .and_return(["https://example.com", nil])

      expect(clipboard_url).to eq("https://example.com")
    end
  end

  describe "#display_options" do
    before do
      # Store original stdout and redirect it
      @original_stdout = $stdout
      @test_stdout = StringIO.new
      $stdout = @test_stdout
    end

    after do
      # Restore original stdout
      $stdout = @original_stdout
    end

    context "with argument provided" do
      it "returns valid JSON with URL info" do
        # Store original ARGV and set test value
        original_argv = ARGV.dup
        stub_const("ARGV", ["https://example.com"])

        # Call the function
        display_options

        # Get output from test stdout
        output = @test_stdout.string

        # Parse the JSON output
        result = JSON.parse(output)

        # Restore original ARGV
        stub_const("ARGV", original_argv)

        expect(result).to have_key("items")
        expect(result["items"].first["title"]).to eq("Clean URL")
        expect(result["items"].first["subtitle"]).to eq("https://example.com")
        expect(result["items"].first["valid"]).to be true
      end
    end

    context "with no argument provided" do
      it "uses clipboard URL when no argument is provided" do
        # Store original ARGV and set to empty
        original_argv = ARGV.dup
        stub_const("ARGV", [])

        # Mock clipboard_url function
        allow(self).to receive(:clipboard_url).and_return("https://clipboard-url.com")

        # Call the function
        display_options

        # Get output from test stdout
        output = @test_stdout.string

        # Parse the JSON output
        result = JSON.parse(output)

        # Restore original ARGV
        stub_const("ARGV", original_argv)

        expect(result["items"].first["subtitle"]).to eq("https://clipboard-url.com")
      end
    end
  end
end
