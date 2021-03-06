require_relative '../spec_helper'

describe AlbumsController do

  before do
    @user = FactoryGirl.create(:person)
  end

  context '#index' do
    context 'shallow route' do
      context 'given a public album' do
        before do
          @public_album = FactoryGirl.create(:album, is_public: true)
          get :index, nil, {logged_in_id: @user.id}
        end

        it 'should list public albums' do
          expect(assigns(:albums)).to include(@public_album)
        end
      end

      context 'given an album owned by a friend' do
        before do
          @friend = FactoryGirl.create(:person)
          Friendship.create!(person: @user, friend: @friend)
          @friend_album = FactoryGirl.create(:album, owner: @friend)
          get :index, nil, {logged_in_id: @user.id}
        end

        it 'should list albums for friends' do
          expect(assigns(:albums)).to include(@friend_album)
        end
      end

      context 'given an album owned by a stranger' do
        before do
          @stranger_album = FactoryGirl.create(:album)
          get :index, nil, {logged_in_id: @user.id}
        end

        it 'should not list albums for strangers' do
          assert_not_include assigns(:albums), @stranger_album
        end
      end
    end

    context 'nested route on person' do
      context 'user is visible' do
        before do
          @album = FactoryGirl.create(:album, owner: @user)
          get :index, {person_id: @user.id}, {logged_in_id: @user.id}
        end

        it 'should list all albums by person' do
          expect(response).to be_success
          expect(assigns(:albums)).to eq([@album])
        end
      end

      context 'user is invisible' do
        before do
          @stranger = FactoryGirl.create(:person, visible: false)
          @album = FactoryGirl.create(:album, owner: @stranger)
          get :index, {person_id: @stranger.id}, {logged_in_id: @user.id}
        end

        it 'should return forbidden' do
          expect(response).to be_forbidden
        end
      end
    end

    context 'nested route on group' do
      before do
        @group = FactoryGirl.create(:group)
        @group.memberships.create!(person: @user)
        @album = FactoryGirl.create(:album, owner: @group)
        get :index, {group_id: @group.id}, {logged_in_id: @user.id}
      end

      it 'should list all albums by group' do
        expect(response).to be_success
        expect(assigns(:albums)).to include(@album)
      end
    end
  end

  context '#show' do
    context 'album owned by user' do
      before do
        @album = FactoryGirl.create(:album, owner: @user)
        get :show, {id: @album.id}, {logged_in_id: @user.id}
      end

      it "should showing an album should redirect to view its pictures" do
        expect(response).to redirect_to(album_pictures_path(@album))
      end
    end
  end

  context '#create' do
    it 'should create an album' do
      get :new, nil, {logged_in_id: @user.id}
      expect(response).to be_success
      before = Album.count
      post :create, {album: {name: 'test name', description: 'test desc', is_public: false}}, {logged_in_id: @user.id}
      expect(response).to be_redirect
      expect(Album.count).to eq(before + 1)
      new_album = Album.last
      expect(new_album.name).to eq("test name")
      expect(new_album.description).to eq("test desc")
    end

    context 'add album to a group' do
      before do
        @group = FactoryGirl.create(:group)
      end

      context 'user is a member of the group' do
        before do
          @group.memberships.create!(person: @user)
          post :create, {group_id: @group.id, album: {name: 'test name'}}, {logged_in_id: @user.id}
        end

        it 'should create an album' do
          expect(response).to be_redirect
        end
      end

      context 'user is not a member of the group' do
        before do
          post :create, {group_id: @group.id, album: {name: 'test name'}}, {logged_in_id: @user.id}
        end

        it 'should return forbidden' do
          expect(response).to be_forbidden
        end
      end

      context 'group does not have pictures enabled' do
        before do
          @group.update_attributes!(pictures: false)
          post :create, {group_id: @group.id, album: {name: 'test name'}}, {logged_in_id: @user.id}
        end

        it 'should return forbidden' do
          expect(response).to be_forbidden
        end
      end

      context 'indicated to remove owner' do
        context 'user is not an admin' do
          before do
            post :create, {person_id: @user.id, album: {name: 'test name', remove_owner: true}}, {logged_in_id: @user.id}
          end

          it 'should still save owner (person) on album' do
            expect(Album.last.owner).to eq(@user)
          end
        end

        context 'user is an admin' do
          before do
            @user.update_attributes(admin: Admin.create!(manage_pictures: true))
            post :create, {person_id: @user.id, album: {name: 'test name', remove_owner: true}}, {logged_in_id: @user.id}
          end

          it 'should not save owner (person) on album' do
            expect(Album.last.owner).to be_nil
          end
        end
      end
    end
  end

  context '#update' do
    context 'album is owned by user' do
      before do
        @album = FactoryGirl.create(:album, owner: @user)
      end

      it 'should edit the album' do
        get :edit, {id: @album.id}, {logged_in_id: @user.id}
        expect(response).to be_success
        post :update, {id: @album.id, album: {name: 'test name', description: 'test desc'}}, {logged_in_id: @user.id}
        expect(response).to redirect_to(album_path(@album))
        expect(@album.reload.name).to eq("test name")
        expect(@album.description).to eq("test desc")
      end
    end

    context 'user does not own album' do
      before do
        @album = FactoryGirl.create(:album)
      end

      it 'should return forbidden' do
        get :edit, {id: @album.id}, {logged_in_id: @user.id}
        expect(response).to be_forbidden
        post :update, {id: @album.id, album: {name: 'test name', description: 'test desc'}}, {logged_in_id: @user.id}
        expect(response).to be_forbidden
      end

      context 'user is admin' do
        before do
          @user.update_attributes(admin: Admin.create!(manage_pictures: true))
        end

        it 'should edit the album' do
          get :edit, {id: @album.id}, {logged_in_id: @user.id}
          expect(response).to be_success
          post :update, {id: @album.id, album: {name: 'test name', description: 'test desc'}}, {logged_in_id: @user.id}
          expect(response).to be_redirect
        end
      end
    end
  end

  context '#destroy' do
    context 'album is owned by user' do
      before do
        @album = FactoryGirl.create(:album, owner: @user)
        post :destroy, {id: @album.id}, {logged_in_id: @user.id}
      end

      it 'should delete the album' do
        assert_raise(ActiveRecord::RecordNotFound) do
          @album.reload
        end
      end

      it 'should redirect to the albums index' do
        expect(response).to redirect_to(albums_path)
      end
    end

    context 'user does not own album' do
      before do
        @album = FactoryGirl.create(:album)
        post :destroy, {id: @album.id}, {logged_in_id: @user.id}
      end

      it 'should return forbidden' do
        expect(response).to be_forbidden
      end

      context 'user is admin' do
        before do
          @user.update_attributes(admin: Admin.create!(manage_pictures: true))
          post :destroy, {id: @album.id}, {logged_in_id: @user.id}
        end

        it 'should delete the album' do
          expect(response).to be_redirect
        end
      end
    end
  end

end
