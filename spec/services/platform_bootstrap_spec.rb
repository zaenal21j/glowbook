require "rails_helper"

RSpec.describe PlatformBootstrap do
  it "prepares reference data and a real administrator without demo businesses or customers" do
    admin = described_class.call(email: " Admin@Example.com ", password: "secure-bootstrap-password")
    expect(admin).to be_admin
    expect(admin.email).to eq("admin@example.com")
    expect(admin.valid_password?("secure-bootstrap-password")).to be(true)
    expect(City.count).to eq(6)
    expect(Category.count).to eq(10)
    expect(Business.count).to eq(0)
    expect(User.count).to eq(1)
  end

  it "can be repeated without changing customized reference data or the existing password" do
    admin = described_class.call(email: "admin@example.com", password: "secure-bootstrap-password")
    City.find_by!(slug: "jakarta").update!(name: "DKI Jakarta")
    Category.find_by!(slug: "facial").update!(name: "Perawatan Wajah")
    expect { described_class.call(email: admin.email) }.not_to change(User, :count)
    expect(City.count).to eq(6)
    expect(Category.count).to eq(10)
    expect(City.find_by!(slug: "jakarta").name).to eq("DKI Jakarta")
    expect(Category.find_by!(slug: "facial").name).to eq("Perawatan Wajah")
    expect(admin.reload.valid_password?("secure-bootstrap-password")).to be(true)
  end

  it "refuses to elevate an existing customer or reset their password" do
    customer = create(:user)
    expect { described_class.call(email: customer.email, password: "secure-bootstrap-password") }
      .to raise_error(ArgumentError, /not an administrator/)
    expect(customer.reload).to be_customer
    expect(customer.valid_password?("password123")).to be(true)
    expect(City.count).to eq(0)
  end

  it "rejects missing email and weak initial passwords before creating reference data" do
    expect { described_class.call(email: "", password: "secure-bootstrap-password") }.to raise_error(ArgumentError)
    expect { described_class.call(email: "admin@example.com", password: "short") }.to raise_error(ArgumentError)
    expect(User.count).to eq(0)
    expect(City.count).to eq(0)
  end
end
