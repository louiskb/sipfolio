class ModelsController < ApplicationController
  # ruby_llm 2.0 owns the model registry (the ruby_llm_models table); read it through RubyLLM.models.
  def index
    @models = RubyLLM.models.all
  end

  def show
    @model = RubyLLM.models.find(params[:id], provider: params[:provider].presence)
  end

  def refresh
    RubyLLM.models.refresh
    redirect_to models_path, notice: "Models refreshed successfully"
  end
end
