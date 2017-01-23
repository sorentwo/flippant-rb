[Flippant::Adapter::Memory].each do |adapter|
  RSpec.describe adapter do
    before do
      Flippant.configure do |config|
        config.adapter = adapter.new
      end
    end

    describe ".add" do
      it "adds to the list of known features" do
        Flippant.add("search")
        Flippant.add("search")
        Flippant.add("delete")

        expect(Flippant.features).to eq(["delete", "search"])
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
      it "adds a feature rule for a group" do
        Flippant.enable("search", "staff", [1])
        Flippant.enable("search", "staff", [])
        Flippant.enable("search", "users", [1])
        Flippant.enable("delete", "staff")

        expect(Flippant.features).to eq(["delete", "search"])
        expect(Flippant.features("staff")).to eq(["delete", "search"])
        expect(Flippant.features("users")).to eq(["search"])
      end
    end

    describe ".disable" do
      it "disables the feature for a group" do
        Flippant.enable("search", "staff", true)
        Flippant.enable("search", "users", false)

        Flippant.disable("search", "users")

        expect(Flippant.features).to eq(["search"])
        expect(Flippant.features("staff")).to eq(["search"])
        expect(Flippant.features("users")).to eq([])
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
        Flippant.register("awesome", ->(actor, ids) { ids.include?(actor[:id]) })

        actor_a = {id: 1}
        actor_b = {id: 5}

        Flippant.enable("search", "awesome", [1, 2, 3])

        expect(Flippant.enabled?("search", actor_a)).to be_truthy
        expect(Flippant.enabled?("search", actor_b)).to be_falsy
      end
    end

    describe "breakdown" do
      it "expands all groups and values" do
        expect(Flippant.breakdown).to eq({})
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
    end

    describe "breakdown" do
      it "works without any features" do
        expect(Flippant.breakdown({id: 1})).to eq({})
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
