require 'rails_helper'

RSpec.describe Review do
  it "is valid with factory defaults" do
    expect(build(:review)).to be_valid
  end

  it "restricts rating to 1..5" do
    expect(build(:review, rating: 0)).not_to be_valid
    expect(build(:review, rating: 6)).not_to be_valid
  end

  it "allows only one review per business per user" do
    review = create(:review)
    dup = build(:review, user: review.user, business: review.business)
    expect(dup).not_to be_valid
  end
end
