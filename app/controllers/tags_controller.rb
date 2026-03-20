class TagsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_tag, only: [:show, :edit, :update, :destroy]

  def index
    @tags = Tag.sorted
  end

  def show
  end

  def new
    @tag = Tag.new
  end

  def create
    @tag = Tag.new(tag_params)
    if @tag.save
      redirect_to tags_path, notice: "Tag created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @tag.update(tag_params)
      redirect_to tags_path, notice: "Tag updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tag.destroy
    redirect_to tags_path, notice: "Tag deleted."
  end

  def merge
    source = Tag.find(params[:source_id])
    target = Tag.find(params[:target_id])

    if source.id == target.id
      redirect_to tags_path, alert: "Cannot merge a tag into itself."
      return
    end

    ActiveRecord::Base.transaction do
      source.transaction_tags.find_each do |tt|
        unless TransactionTag.exists?(transaction_id: tt.transaction_id, tag_id: target.id)
          tt.update!(tag_id: target.id)
        else
          tt.destroy!
        end
      end

      source.destroy!
    end

    redirect_to tags_path, notice: "\"#{source.name}\" merged into \"#{target.name}\"."
  end

  private

  def set_tag
    @tag = Tag.find(params[:id])
  end

  def tag_params
    params.require(:tag).permit(:name, :color)
  end
end
