[Flippant::Adapter::Memory, Flippant::Adapter::Redis].each do |adapter|
  RSpec.describe adapter do
    before do
      Flippant.configure do |config|
        config.adapter = adapter.new
      end

      Flippant.clear
    end

    describe ".register" do
      it "accepts a proc or a block" do
        Flippant.register("awesome", ->(_, _) { true })
        Flippant.register("greatest") { |_, _| true }

        expect(Flippant.registered.keys).to eq(%w[awesome greatest])
      end
    end

    describe ".add" do
      it "adds to the list of known features" do
        Flippant.add("search")
        Flippant.add("search")
        Flippant.add("delete")

        expect(Flippant.features).to eq(%w[delete search])
      end

      it "normalizes feature names" do
        Flippant.add(:search)
        Flippant.add("Search")
        Flippant.add(" search ")
        Flippant.add("\nSEARCH\t")

        expect(Flippant.features).to eq(["search"])
      end
    end

    describe ".clear" do
      it "removes all known groups and features" do
        Flippant.add("search")
        Flippant.register("awesome", ->(_, _) { true })

        expect(Flippant.features).not_to eq([])
        expect(Flippant.registered).not_to eq({})

        Flippant.clear

        expect(Flippant.features).to eq([])
        expect(Flippant.registered).to eq({})
      end

      it "can remove either groups or features" do
        Flippant.add("search")
        Flippant.register("awesome", ->(_, _) { true })

        Flippant.clear(:features)

        expect(Flippant.features).to eq([])
        expect(Flippant.registered).not_to eq({})

        Flippant.clear(:groups)

        expect(Flippant.registered).to eq({})
      end
    end

    describe ".remove" do
      it "removes only a specific feature" do
        Flippant.add("search")
        Flippant.add("delete")

        Flippant.remove("search")
        expect(Flippant.features).to eq(["delete"])

        Flippant.remove("delete")
        expect(Flippant.features).to be_empty

        Flippant.remove("unknown")
        expect(Flippant.features).to be_empty
      end
    end

    describe ".enable" do
      before do
        Flippant.register("staff", ->(_, _) { true })
        Flippant.register("users", ->(_, _) { true })
      end

      it "adds a feature rule for a group" do
        Flippant.enable("search", "staff", [1])
        Flippant.enable("search", "users", [1])
        Flippant.enable("delete", "staff")
        Flippant.enable(:delete, :staff)

        expect(Flippant.features).to eq(%w[delete search])
        expect(Flippant.features("staff")).to eq(%w[delete search])
        expect(Flippant.features("users")).to eq(["search"])
      end

      it "does not enable features for unknown groups" do
        expect do
          Flippant.enable("search", "not-a-real-group")
        end.to raise_error(Flippant::Error)
      end

      it "merges additional values" do
        Flippant.enable("search", "users", [1, 2])
        Flippant.enable("search", "users", [3])
        Flippant.enable("search", "users", [1])

        expect(Flippant.breakdown).to eq(
          "search" => {"users" => [1, 2, 3]}
        )
      end

      it "ensures that values remain sorted" do
        Flippant.enable("search", "users", [3, 1])
        Flippant.enable("search", "users", [4, 2])

        expect(Flippant.breakdown).to eq(
          "search" => {"users" => [1, 2, 3, 4]}
        )
      end

      it "operates atomically to avoid race conditions" do
        threads = [
          Thread.new { Flippant.enable("search", "users", [1, 2]) },
          Thread.new { Flippant.enable("search", "users", [3, 4]) },
          Thread.new { Flippant.enable("search", "users", [5, 6]) }
        ]

        threads.each(&:join)

        expect(Flippant.breakdown).to eq(
          "search" => {"users" => [1, 2, 3, 4, 5, 6]}
        )
      end
    end

    describe ".disable" do
      before do
        Flippant.register("staff", ->(_, _) { true })
        Flippant.register("users", ->(_, _) { true })
      end

      it "disables the feature for a group" do
        Flippant.enable("search", "staff")
        Flippant.enable("search", "users")

        Flippant.disable("search", "users")
        Flippant.disable(:search, :users)

        expect(Flippant.features).to eq(["search"])
        expect(Flippant.features("staff")).to eq(["search"])
        expect(Flippant.features("users")).to eq([])
      end

      it "retains the group and removes values" do
        Flippant.enable("search", "users", [1, 2])
        Flippant.disable("search", "users", [2])

        expect(Flippant.breakdown).to eq(
          "search" => {"users" => [1]}
        )
      end

      it "allows symbol-based group names" do
        Flippant.enable("search", :members, [1])
        Flippant.disable("search", :members, [1])

        expect(Flippant.breakdown).to eq(
          "search" => {"members" => []}
        )
      end

      it "operates atomically to avoid race conditions" do
        Flippant.enable("search", "users", [1, 2, 3, 4, 5])

        threads = [
          Thread.new { Flippant.disable("search", "users", [1]) },
          Thread.new { Flippant.disable("search", "users", [3]) },
          Thread.new { Flippant.disable("search", "users", [5]) }
        ]

        threads.each(&:join)

        expect(Flippant.breakdown).to eq(
          "search" => {"users" => [2, 4]}
        )
      end
    end

    describe ".rename" do
      before do
        Flippant.register("members", ->(_, _) { true })
      end

      it "renames an existing feature" do
        Flippant.enable("search", "members", [1])

        Flippant.rename("search", "super-search")

        expect(Flippant.features).to eq(["super-search"])
      end

      it "normalizes values while renaming" do
        Flippant.enable("search", "members")

        Flippant.rename(" SEARCH ", " SUPER-SEARCH ")

        expect(Flippant.features).to eq(["super-search"])
      end

      it "clobbers an existing feature with the same name" do
        Flippant.enable("search", "members", [1])
        Flippant.enable("super-search", "members", [2])

        Flippant.rename(:search, :"super-search")

        expect(Flippant.breakdown).to eq(
          "super-search" => {"members" => [1]}
        )
      end
    end

    describe ".enabled?" do
      it "checks a feature for an actor" do
        Flippant.register("staff", ->(actor, _values) { actor[:staff?] })

        actor_a = {id: 1, staff?: true}
        actor_b = {id: 2, staff?: false}

        expect(Flippant.enabled?("search", actor_a)).to be_falsy
        expect(Flippant.enabled?("search", actor_b)).to be_falsy

        Flippant.enable("search", "staff")

        expect(Flippant.enabled?("search", actor_a)).to be_truthy
        expect(Flippant.enabled?("search", actor_b)).to be_falsy
        expect(Flippant.enabled?(:search, actor_a)).to be_truthy
      end

      it "checks for a feature against multiple groups" do
        Flippant.register("awesome", ->(actor, _) { actor[:awesome?] })
        Flippant.register("radical", ->(actor, _) { actor[:radical?] })

        actor_a = {id: 1, awesome?: true, radical?: false}
        actor_b = {id: 2, awesome?: false, radical?: true}
        actor_c = {id: 3, awesome?: false, radical?: false}

        Flippant.enable("search", "awesome")
        Flippant.enable("search", "radical")

        expect(Flippant.enabled?("search", actor_a)).to be_truthy
        expect(Flippant.enabled?("search", actor_b)).to be_truthy
        expect(Flippant.enabled?("search", actor_c)).to be_falsy
      end

      it "uses rule values when checking" do
        Flippant.register("great", ->(actor, ids) { ids.include?(actor[:id]) })

        actor_a = {id: 1}
        actor_b = {id: 5}

        Flippant.enable("search", "great", [1, 2, 3])

        expect(Flippant.enabled?("search", actor_a)).to be_truthy
        expect(Flippant.enabled?("search", actor_b)).to be_falsy
      end
    end

    describe ".exists?" do
      it "checks whether a feature exists" do
        Flippant.add("search")

        expect(Flippant.exists?("search")).to be_truthy
        expect(Flippant.exists?(:search)).to be_truthy
        expect(Flippant.exists?("breach")).to be_falsy
      end

      it "checks whether a feature and group exist" do
        Flippant.register("nobody", ->(_, _) { true })
        Flippant.enable("search", "nobody")

        expect(Flippant.exists?("search", "nobody")).to be_truthy
        expect(Flippant.exists?("search", "everybody")).to be_falsy
      end
    end

    describe ".breakdown" do
      it "expands all groups and values" do
        expect(Flippant.breakdown).to eq({})
      end

      it "works without any features" do
        expect(Flippant.breakdown(id: 1)).to eq({})
      end

      it "lists all features with their metadata" do
        Flippant.register("awesome", ->(_, _) { true })
        Flippant.register("radical", ->(_, _) { false })
        Flippant.register("heinous", ->(_, _) { false })

        Flippant.enable("search", "awesome")
        Flippant.enable("search", "heinous", [1, 2])
        Flippant.enable("delete", "radical")
        Flippant.enable("invite", "heinous", [5, 6])

        expect(Flippant.breakdown).to eq(
          "search" => {"awesome" => [], "heinous" => [1, 2]},
          "delete" => {"radical" => []},
          "invite" => {"heinous" => [5, 6]}
        )
      end

      it "lists all enabled features for an actor" do
        Flippant.register("awesome", ->(actor, _) { actor[:awesome?] })
        Flippant.register("radical", ->(actor, _) { actor[:radical?] })
        Flippant.register("heinous", ->(actor, _) { !actor[:awesome?] })

        actor = {id: 1, awesome?: true, radical?: true}

        Flippant.enable("search", "awesome")
        Flippant.enable("search", "heinous")
        Flippant.enable("delete", "radical")
        Flippant.enable("invite", "heinous")

        breakdown = Flippant.breakdown(actor)

        expect(breakdown.keys).to contain_exactly("delete", "invite", "search")

        expect(breakdown).to eq(
          "delete" => true,
          "invite" => false,
          "search" => true
        )
      end
    end
  end
end
