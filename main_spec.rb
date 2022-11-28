require 'dry/container/stub'
require 'rspec'

require './main'


RSpec.describe Repositories::Tasks do
  it 'is empty initially' do
    expect(subject.list).to be_empty
  end

  context 'with tasks' do
    let(:priority0) { double('priority0', value: Models::Priority::HIGH) }
    let(:priority1) { double('priority1', value: Models::Priority::MEDIUM) }
    let(:task0) { double('task0', id: 0, priority: priority0) }
    let(:task1) { double('task1', id: 1, priority: priority1) }

    before do
      subject.add(task0)
      subject.add(task1)
    end

    describe '#list' do
      it 'returns all tasks' do
        expect(subject.list).to eq([task0, task1])
      end
    end

    describe '#find_by_id' do
      it 'returns task for the specified id' do
        expect(subject.find_by_id(task0.id)).to eq(task0)
      end

      it 'returns nil if not found' do
        expect(subject.find_by_id(2)).to be_nil
      end
    end

    describe '#remove_by_id' do
      it 'removes task with specified id' do
        expect { subject.remove_by_id(task0.id) }
          .to change { subject.list.size }.by(-1)
      end

      it 'does not remove if not found' do
        expect { subject.remove_by_id(2) }
          .not_to change { subject.list.size }
      end
    end
  end
end


RSpec.describe UseCases::AddTask do
  let(:enumerator) { double('enumerator', next: 1) }
  let(:task_factory) { Factories::Task.new(enumerator: enumerator) }
  let(:tasks_repository)  { double('tasks_repository', add: nil) }
  let(:text) { 'Test text' }

  subject do
    described_class.new(
      task_factory: task_factory,
      tasks_repository: tasks_repository,
    )
  end

  it 'adds task to the repository' do
    subject.call(text)

    expect(tasks_repository).to have_received(:add).with(Models::Task) do |task|
      expect(task.priority.min?).to be_truthy
      expect(task.text).to eq(text)
    end
  end
end


RSpec.describe 'A container test' do
  let(:task) do
    Models::Task.new(
      id: 1,
      text: 'Example text.',
      priority: Models::Priority.low
    )
  end
  let(:tasks_repository) do
    double('tasks_repository', add: nil, list: [task])
  end

  subject { Container.build }

  before do
    subject.enable_stubs!
    subject.stub('todo.tasks_repository', tasks_repository)
  end

  it 'prints added task' do
    print_tasks = subject.resolve('todo.print_tasks')

    expect { print_tasks.call }.to output("- 1: Example text.\n").to_stdout
  end
end
